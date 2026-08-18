import { LobbyService } from './lobby.service';

describe('LobbyService Gate 1 summary', () => {
  it('composes exactly two daily missions and one shared recommendation', async () => {
    const profileService = {
      getProfileData: jest.fn().mockResolvedValue({
        id: 'user-1',
        username: 'player',
        fullName: null,
        target: 'cpns',
        characterId: 'character-basic-squire',
        towerId: 'tower-garda-biru',
        tier: 'warrior',
        rankPoints: 450,
        yCoins: 100,
        streak: { current: 2, best: 5, lastDate: '2026-08-17' },
      }),
    };
    const recommendation = {
      type: 'practice',
      target: 'cpns',
      reason: 'Latihan umum.',
      metrics: { sampleSize: 0, accuracy: null, lastPracticedAt: null },
    };
    const analyticsService = {
      getAnalyticsData: jest.fn().mockResolvedValue({ recommendation }),
    };
    const hiredPassService = {
      getStatus: jest.fn().mockResolvedValue({
        data: {
          season: { id: 'beta-2026-08' },
          passPoints: 120,
          entitlement: { premiumActive: false, expiresAt: null },
          missions: [{ completed: true }],
          rewards: [{ id: 'reward-1' }],
          claimedRewardIds: [],
        },
      }),
    };
    const secondEq = jest.fn().mockResolvedValue({
      data: [
        {
          mission_key: 'daily_practice',
          completed_at: '2026-08-17T01:00:00Z',
          reward_rank_points: 50,
        },
      ],
      error: null,
    });
    const firstEq = jest.fn().mockReturnValue({ eq: secondEq });
    const supabaseService = {
      getClient: () => ({
        from: () => ({ select: () => ({ eq: firstEq }) }),
      }),
    };
    const service = new LobbyService(
      profileService as any,
      analyticsService as any,
      hiredPassService as any,
      supabaseService as any,
    );

    const result = await service.getSummary(
      'user-1',
      new Date('2026-08-17T05:00:00Z'),
    );

    expect(result.data.dailyMissions).toHaveLength(2);
    expect(result.data.dailyMissions[0]).toMatchObject({
      key: 'daily_practice',
      progress: 1,
      completed: true,
      businessDate: '2026-08-17',
    });
    expect(result.data.dailyMissions[1]).toMatchObject({
      key: 'daily_pvp',
      progress: 0,
      completed: false,
    });
    expect(result.data.recommendation).toBe(recommendation);
  });
});
