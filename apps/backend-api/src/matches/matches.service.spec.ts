import { MatchesService } from './matches.service';

describe('MatchesService', () => {
  it('returns Private history as a human match with zero progression', async () => {
    const range = jest.fn().mockResolvedValue({
      data: [
        {
          id: 'result-private',
          room_id: 'room-private',
          player_a_id: 'user-a',
          player_b_id: 'user-b',
          winner_user_id: 'user-a',
          mode: 'private',
          target: 'cpns',
          reason: 'hp_zero',
          player_a_hp: 60,
          player_b_hp: 0,
          player_a_points: 35,
          player_b_points: 10,
          rating_delta_a: 0,
          rating_delta_b: 0,
          coins_delta_a: 0,
          coins_delta_b: 0,
          ended_at: '2026-08-18T02:00:00.000Z',
        },
      ],
      error: null,
    });
    const query = {
      select: jest.fn(),
      or: jest.fn(),
      order: jest.fn(),
      range,
    };
    query.select.mockReturnValue(query);
    query.or.mockReturnValue(query);
    query.order.mockReturnValue(query);
    const service = new MatchesService({
      getClient: () => ({ from: () => query }),
    } as never);

    const result = await service.getHistory('user-a', {});

    expect(result.data[0]).toEqual(
      expect.objectContaining({
        mode: 'private',
        opponentId: 'user-b',
        isBotMatch: false,
        ratingDelta: 0,
        coinsDelta: 0,
      }),
    );
  });
});
