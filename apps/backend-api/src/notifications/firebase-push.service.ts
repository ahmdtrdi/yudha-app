import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, type Message } from 'firebase-admin/messaging';
import type { ClaimedNotificationDelivery } from './notification.types';
import { notificationContent } from './notification-content';

@Injectable()
export class FirebasePushService {
  private readonly logger = new Logger(FirebasePushService.name);
  private readonly enabled: boolean;
  private readonly publicUrl: string | null;

  constructor(private readonly configService: ConfigService) {
    this.enabled =
      this.configService.get<string>('NOTIFICATIONS_ENABLED') === 'true';

    if (!this.enabled) {
      this.publicUrl = null;
      this.logger.log('FCM reminder delivery is disabled.');
      return;
    }

    this.publicUrl = this.required('APP_PUBLIC_URL').replace(/\/$/, '');
    const parsedPublicUrl = new URL(this.publicUrl);
    if (parsedPublicUrl.protocol !== 'https:') {
      throw new Error(
        'APP_PUBLIC_URL must use HTTPS when notifications are enabled.',
      );
    }
    const projectId = this.required('FIREBASE_PROJECT_ID');
    const clientEmail = this.required('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.required('FIREBASE_PRIVATE_KEY').replace(
      /\\n/g,
      '\n',
    );
    if (!getApps().some((app) => app.name === 'yudha-notifications')) {
      initializeApp(
        { credential: cert({ projectId, clientEmail, privateKey }), projectId },
        'yudha-notifications',
      );
    }
    this.logger.log('Firebase Cloud Messaging initialized.');
  }

  get isEnabled(): boolean {
    return this.enabled;
  }

  async send(delivery: ClaimedNotificationDelivery): Promise<string> {
    if (!this.enabled) throw new Error('FCM delivery is disabled.');
    const app = getApps().find(
      (candidate) => candidate.name === 'yudha-notifications',
    );
    if (!app) throw new Error('Firebase app is not initialized.');

    const content = notificationContent(delivery);
    const remainingMs = Math.max(
      0,
      new Date(delivery.expiresAt).getTime() - Date.now(),
    );
    const collapseKey = `${delivery.kind}-${delivery.businessDate}`;
    const webLink = this.publicUrl
      ? new URL(content.route, `${this.publicUrl}/`)
      : null;
    webLink?.searchParams.set('notificationDeliveryId', delivery.deliveryId);
    const message: Message = {
      token: delivery.fcmToken,
      notification: { title: content.title, body: content.body },
      data: {
        type: delivery.kind,
        deliveryId: delivery.deliveryId,
        route: content.route,
        businessDate: delivery.businessDate,
      },
      android: {
        priority: 'normal',
        ttl: remainingMs,
        collapseKey,
        notification: { channelId: 'daily_reminders' },
      },
      webpush: {
        headers: {
          TTL: String(Math.floor(remainingMs / 1000)),
          Urgency: 'normal',
          Topic: collapseKey,
        },
        fcmOptions: webLink ? { link: webLink.toString() } : undefined,
      },
    };
    return getMessaging(app).send(message);
  }

  isPermanentError(error: unknown): boolean {
    const code =
      typeof error === 'object' && error && 'code' in error
        ? String((error as { code: unknown }).code)
        : '';
    return [
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
      'messaging/mismatched-credential',
    ].includes(code);
  }

  errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }

  private required(name: string): string {
    const value = this.configService.get<string>(name)?.trim();
    if (!value)
      throw new Error(`${name} is required when notifications are enabled.`);
    return value;
  }
}
