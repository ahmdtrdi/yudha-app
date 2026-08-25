import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { FirebasePushService } from './firebase-push.service';
import type { ClaimedNotificationDelivery } from './notification.types';
import { NotificationsService } from './notifications.service';

@Injectable()
export class NotificationSchedulerService {
  private readonly logger = new Logger(NotificationSchedulerService.name);

  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly firebasePushService: FirebasePushService,
  ) {}

  @Cron('* * * * *', {
    name: 'daily-reminder-notifications',
    waitForCompletion: true,
  })
  async dispatchDueNotifications(): Promise<void> {
    if (!this.firebasePushService.isEnabled) return;
    const deliveries = await this.notificationsService.claimDueDeliveries(500);
    for (let index = 0; index < deliveries.length; index += 20) {
      await Promise.all(
        deliveries
          .slice(index, index + 20)
          .map((delivery) => this.dispatch(delivery)),
      );
    }
    if (deliveries.length > 0) {
      this.logger.log(`Processed ${deliveries.length} reminder deliveries.`);
    }
  }

  private async dispatch(delivery: ClaimedNotificationDelivery): Promise<void> {
    try {
      const messageId = await this.firebasePushService.send(delivery);
      await this.notificationsService.markSent(delivery.deliveryId, messageId);
    } catch (error) {
      const message = this.firebasePushService.errorMessage(error);
      const permanent = this.firebasePushService.isPermanentError(error);
      this.logger.warn(`Reminder ${delivery.deliveryId} failed: ${message}`);
      await this.notificationsService.markFailed(delivery, message, permanent);
    }
  }
}
