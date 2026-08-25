export type NotificationPlatform = 'android' | 'web';
export type NotificationKind = 'morning' | 'rescue';

export interface NotificationPreferences {
  enabled: boolean;
  morningEnabled: boolean;
  morningTime: string;
  rescueEnabled: boolean;
  rescueTime: string;
}

export interface ClaimedNotificationDelivery {
  deliveryId: string;
  userId: string;
  installationId: string;
  fcmToken: string;
  platform: NotificationPlatform;
  timeZone: string;
  kind: NotificationKind;
  localDate: string;
  businessDate: string;
  currentStreak: number;
  remainingMissionKeys: string[];
  expiresAt: string;
  attemptCount: number;
}
