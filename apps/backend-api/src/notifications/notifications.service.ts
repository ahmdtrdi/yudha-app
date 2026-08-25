import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import type { Database } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';
import type {
  ClaimedNotificationDelivery,
  NotificationPlatform,
  NotificationPreferences,
} from './notification.types';

const DEFAULT_PREFERENCES: NotificationPreferences = {
  enabled: false,
  morningEnabled: true,
  morningTime: '09:00',
  rescueEnabled: true,
  rescueTime: '19:30',
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;

type NotificationPreferencesRow = Pick<
  Database['public']['Tables']['notification_preferences']['Row'],
  | 'enabled'
  | 'morning_enabled'
  | 'morning_time'
  | 'rescue_enabled'
  | 'rescue_time'
>;

@Injectable()
export class NotificationsService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getPreferences(userId: string): Promise<NotificationPreferences> {
    const { data, error } = await this.db
      .from('notification_preferences')
      .select(
        'enabled, morning_enabled, morning_time, rescue_enabled, rescue_time',
      )
      .eq('user_id', userId)
      .maybeSingle();

    this.throwOnError(error);
    return data ? this.mapPreferences(data) : DEFAULT_PREFERENCES;
  }

  async updatePreferences(
    userId: string,
    input: Record<string, unknown>,
  ): Promise<NotificationPreferences> {
    const allowed = new Set([
      'enabled',
      'morningEnabled',
      'morningTime',
      'rescueEnabled',
      'rescueTime',
    ]);
    const keys = Object.keys(input);
    if (keys.length === 0 || keys.some((key) => !allowed.has(key))) {
      throw new BadRequestException('Notification preferences are invalid.');
    }

    const existing = await this.getPreferences(userId);
    const next: NotificationPreferences = {
      enabled: this.booleanValue(input.enabled, existing.enabled, 'enabled'),
      morningEnabled: this.booleanValue(
        input.morningEnabled,
        existing.morningEnabled,
        'morningEnabled',
      ),
      morningTime: this.timeValue(
        input.morningTime,
        existing.morningTime,
        'morningTime',
      ),
      rescueEnabled: this.booleanValue(
        input.rescueEnabled,
        existing.rescueEnabled,
        'rescueEnabled',
      ),
      rescueTime: this.timeValue(
        input.rescueTime,
        existing.rescueTime,
        'rescueTime',
      ),
    };

    const { data, error } = await this.db
      .from('notification_preferences')
      .upsert(
        {
          user_id: userId,
          enabled: next.enabled,
          morning_enabled: next.morningEnabled,
          morning_time: next.morningTime,
          rescue_enabled: next.rescueEnabled,
          rescue_time: next.rescueTime,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id' },
      )
      .select(
        'enabled, morning_enabled, morning_time, rescue_enabled, rescue_time',
      )
      .single();

    this.throwOnError(error);
    if (!data) {
      throw new InternalServerErrorException(
        'Notification preferences were not returned.',
      );
    }
    return this.mapPreferences(data);
  }

  async registerInstallation(
    userId: string,
    installationId: string,
    input: Record<string, unknown>,
  ) {
    if (!UUID_PATTERN.test(installationId)) {
      throw new BadRequestException('installationId must be a UUID.');
    }
    if (typeof input.token !== 'string') {
      throw new BadRequestException('FCM token is invalid.');
    }
    const token = input.token.trim();
    if (token.length < 20 || token.length > 4096) {
      throw new BadRequestException('FCM token is invalid.');
    }
    const platform = input.platform;
    if (platform !== 'android' && platform !== 'web') {
      throw new BadRequestException('platform must be android or web.');
    }
    if (typeof input.timeZone !== 'string') {
      throw new BadRequestException('timeZone must be a valid IANA time zone.');
    }
    const timeZone = input.timeZone.trim();
    if (!this.isTimeZone(timeZone)) {
      throw new BadRequestException('timeZone must be a valid IANA time zone.');
    }
    const allowed = new Set(['token', 'platform', 'timeZone']);
    if (Object.keys(input).some((key) => !allowed.has(key))) {
      throw new BadRequestException('Installation payload is invalid.');
    }

    const now = new Date().toISOString();
    const conflicting = await this.db
      .from('push_installations')
      .select('user_id, installation_id')
      .eq('fcm_token', token)
      .maybeSingle();
    this.throwOnError(conflicting.error);
    if (
      conflicting.data &&
      (conflicting.data.user_id !== userId ||
        conflicting.data.installation_id !== installationId)
    ) {
      await this.cancelPendingDeliveries(
        conflicting.data.user_id,
        conflicting.data.installation_id,
      );
      const removed = await this.db
        .from('push_installations')
        .delete()
        .eq('user_id', conflicting.data.user_id)
        .eq('installation_id', conflicting.data.installation_id);
      this.throwOnError(removed.error);
    }

    const { data, error } = await this.db
      .from('push_installations')
      .upsert(
        {
          user_id: userId,
          installation_id: installationId,
          fcm_token: token,
          platform,
          time_zone: timeZone,
          authorized: true,
          active: true,
          last_seen_at: now,
          updated_at: now,
        },
        { onConflict: 'user_id,installation_id' },
      )
      .select('installation_id, platform, time_zone, last_seen_at')
      .single();
    this.throwOnError(error);
    if (!data) {
      throw new InternalServerErrorException(
        'Push installation was not returned.',
      );
    }

    return {
      installationId: data.installation_id,
      platform: data.platform,
      timeZone: data.time_zone,
      lastSeenAt: data.last_seen_at,
    };
  }

  async removeInstallation(userId: string, installationId: string) {
    if (!UUID_PATTERN.test(installationId)) {
      throw new BadRequestException('installationId must be a UUID.');
    }
    await this.cancelPendingDeliveries(userId, installationId);
    const { error } = await this.db
      .from('push_installations')
      .delete()
      .eq('user_id', userId)
      .eq('installation_id', installationId);
    this.throwOnError(error);
    return { removed: true };
  }

  async markOpened(userId: string, deliveryId: string) {
    if (!UUID_PATTERN.test(deliveryId)) {
      throw new BadRequestException('deliveryId must be a UUID.');
    }
    const openedAt = new Date().toISOString();
    const { data, error } = await this.db
      .from('notification_deliveries')
      .update({ opened_at: openedAt, updated_at: openedAt })
      .eq('id', deliveryId)
      .eq('user_id', userId)
      .select('id, opened_at')
      .maybeSingle();
    this.throwOnError(error);
    if (!data) {
      throw new NotFoundException('Notification delivery was not found.');
    }
    return { deliveryId: data.id, openedAt: data.opened_at };
  }

  async claimDueDeliveries(
    limit = 100,
  ): Promise<ClaimedNotificationDelivery[]> {
    const { data, error } = await this.db.rpc(
      'claim_due_notification_deliveries',
      { p_now: new Date().toISOString(), p_limit: limit },
    );
    this.throwOnError(error);
    return (data ?? []).map((row) => ({
      deliveryId: String(row.delivery_id),
      userId: String(row.user_id),
      installationId: String(row.installation_id),
      fcmToken: String(row.fcm_token),
      platform: row.platform as NotificationPlatform,
      timeZone: String(row.time_zone),
      kind: row.kind as 'morning' | 'rescue',
      localDate: String(row.local_date),
      businessDate: String(row.business_date),
      currentStreak: Number(row.current_streak ?? 0),
      remainingMissionKeys: Array.isArray(row.remaining_mission_keys)
        ? row.remaining_mission_keys.map(String)
        : [],
      expiresAt: String(row.expires_at),
      attemptCount: Number(row.attempt_count ?? 0),
    }));
  }

  async markSent(deliveryId: string, messageId: string): Promise<void> {
    const now = new Date().toISOString();
    const { error } = await this.db
      .from('notification_deliveries')
      .update({
        status: 'sent',
        fcm_message_id: messageId,
        sent_at: now,
        lease_until: null,
        last_error: null,
        updated_at: now,
      })
      .eq('id', deliveryId);
    this.throwOnError(error);
  }

  async markFailed(
    delivery: ClaimedNotificationDelivery,
    errorMessage: string,
    permanent: boolean,
  ): Promise<void> {
    const now = new Date();
    const exhausted = permanent || delivery.attemptCount >= 3;
    const delayMinutes = Math.min(
      8,
      2 ** Math.max(0, delivery.attemptCount - 1),
    );
    const { error } = await this.db
      .from('notification_deliveries')
      .update({
        status: exhausted ? 'failed' : 'pending',
        next_attempt_at: new Date(
          now.getTime() + delayMinutes * 60_000,
        ).toISOString(),
        lease_until: null,
        last_error: errorMessage.slice(0, 1000),
        updated_at: now.toISOString(),
      })
      .eq('id', delivery.deliveryId);
    this.throwOnError(error);

    if (permanent) {
      const disabled = await this.db
        .from('push_installations')
        .update({ active: false, updated_at: now.toISOString() })
        .eq('user_id', delivery.userId)
        .eq('installation_id', delivery.installationId);
      this.throwOnError(disabled.error);
    }
  }

  private get db() {
    return this.supabaseService.getClient();
  }

  private async cancelPendingDeliveries(
    userId: string,
    installationId: string,
  ): Promise<void> {
    const now = new Date().toISOString();
    const { error } = await this.db
      .from('notification_deliveries')
      .update({ status: 'cancelled', lease_until: null, updated_at: now })
      .eq('user_id', userId)
      .eq('installation_id', installationId)
      .in('status', ['pending', 'processing']);
    this.throwOnError(error);
  }

  private mapPreferences(
    row: NotificationPreferencesRow,
  ): NotificationPreferences {
    return {
      enabled: Boolean(row.enabled),
      morningEnabled: Boolean(row.morning_enabled),
      morningTime: String(row.morning_time).slice(0, 5),
      rescueEnabled: Boolean(row.rescue_enabled),
      rescueTime: String(row.rescue_time).slice(0, 5),
    };
  }

  private booleanValue(
    value: unknown,
    fallback: boolean,
    name: string,
  ): boolean {
    if (value === undefined) return fallback;
    if (typeof value !== 'boolean') {
      throw new BadRequestException(`${name} must be a boolean.`);
    }
    return value;
  }

  private timeValue(value: unknown, fallback: string, name: string): string {
    if (value === undefined) return fallback;
    if (typeof value !== 'string' || !TIME_PATTERN.test(value)) {
      throw new BadRequestException(`${name} must use HH:mm.`);
    }
    return value;
  }

  private isTimeZone(value: string): boolean {
    if (value.length === 0 || value.length > 100) return false;
    try {
      new Intl.DateTimeFormat('en-US', { timeZone: value }).format();
      return true;
    } catch {
      return false;
    }
  }

  private throwOnError(error: { message?: string } | null): void {
    if (error) {
      throw new InternalServerErrorException(
        error.message ?? 'Notification storage failed.',
      );
    }
  }
}
