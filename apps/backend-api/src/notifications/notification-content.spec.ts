import { notificationContent } from './notification-content';
import type { ClaimedNotificationDelivery } from './notification.types';

function delivery(
  overrides: Partial<ClaimedNotificationDelivery> = {},
): ClaimedNotificationDelivery {
  return {
    deliveryId: 'delivery-1',
    userId: 'user-1',
    installationId: 'installation-1',
    fcmToken: 'token',
    platform: 'android',
    timeZone: 'Asia/Jakarta',
    kind: 'morning',
    localDate: '2026-08-25',
    businessDate: '2026-08-25',
    currentStreak: 5,
    remainingMissionKeys: ['daily_practice', 'daily_pvp'],
    expiresAt: '2026-08-25T17:00:00.000Z',
    attemptCount: 1,
    ...overrides,
  };
}

describe('notificationContent', () => {
  it('routes a two-mission morning reminder to Lobby', () => {
    expect(notificationContent(delivery())).toMatchObject({ route: '/' });
  });

  it.each([
    ['daily_practice', '/practice'],
    ['daily_pvp', '/pvp'],
  ])('routes the remaining %s mission', (missionKey, route) => {
    expect(
      notificationContent(delivery({ remainingMissionKeys: [missionKey] }))
        .route,
    ).toBe(route);
  });

  it('uses the current streak and Practice route for rescue reminders', () => {
    expect(
      notificationContent(delivery({ kind: 'rescue', currentStreak: 12 })),
    ).toMatchObject({
      title: 'Streak 12 harimu belum aman',
      route: '/practice',
    });
  });
});
