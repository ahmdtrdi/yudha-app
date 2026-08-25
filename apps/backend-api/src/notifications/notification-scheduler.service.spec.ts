import { FirebasePushService } from './firebase-push.service';
import { NotificationSchedulerService } from './notification-scheduler.service';
import { NotificationsService } from './notifications.service';

describe('NotificationSchedulerService', () => {
  it('does not claim deliveries while the feature flag is disabled', async () => {
    const notifications = { claimDueDeliveries: jest.fn() };
    const push = { isEnabled: false };
    const scheduler = new NotificationSchedulerService(
      notifications as unknown as NotificationsService,
      push as unknown as FirebasePushService,
    );

    await scheduler.dispatchDueNotifications();

    expect(notifications.claimDueDeliveries).not.toHaveBeenCalled();
  });

  it('marks successful deliveries sent', async () => {
    const delivery = { deliveryId: 'delivery-1' };
    const notifications = {
      claimDueDeliveries: jest.fn().mockResolvedValue([delivery]),
      markSent: jest.fn().mockResolvedValue(undefined),
      markFailed: jest.fn(),
    };
    const push = {
      isEnabled: true,
      send: jest.fn().mockResolvedValue('message-1'),
      errorMessage: jest.fn(),
      isPermanentError: jest.fn(),
    };
    const scheduler = new NotificationSchedulerService(
      notifications as unknown as NotificationsService,
      push as unknown as FirebasePushService,
    );

    await scheduler.dispatchDueNotifications();

    expect(notifications.markSent).toHaveBeenCalledWith(
      'delivery-1',
      'message-1',
    );
    expect(notifications.markFailed).not.toHaveBeenCalled();
  });
});
