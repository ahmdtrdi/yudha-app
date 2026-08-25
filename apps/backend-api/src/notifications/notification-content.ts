import type { ClaimedNotificationDelivery } from './notification.types';

export interface NotificationContent {
  title: string;
  body: string;
  route: '/' | '/practice' | '/pvp';
}

export function notificationContent(
  delivery: ClaimedNotificationDelivery,
): NotificationContent {
  if (delivery.kind === 'rescue') {
    return {
      title: `Streak ${delivery.currentStreak} harimu belum aman`,
      body: 'Selesaikan satu sesi Practice sebelum hari ini berakhir.',
      route: '/practice',
    };
  }

  const remaining = delivery.remainingMissionKeys;
  if (remaining.length === 1 && remaining[0] === 'daily_practice') {
    return {
      title: 'Tinggal satu misi hari ini',
      body: 'Selesaikan Practice untuk mendapatkan 50 poin rank.',
      route: '/practice',
    };
  }
  if (remaining.length === 1 && remaining[0] === 'daily_pvp') {
    return {
      title: 'Tinggal satu misi hari ini',
      body: 'Selesaikan PvP publik untuk mendapatkan 80 poin rank.',
      route: '/pvp',
    };
  }
  return {
    title: 'Misi hari ini sudah siap',
    body: 'Selesaikan Practice atau PvP dan mulai progres harianmu.',
    route: '/',
  };
}
