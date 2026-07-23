import { Test, TestingModule } from '@nestjs/testing';
import { MatchResultService } from './match-result.service';
import { SupabaseService } from '../../supabase/supabase.service';
import type { InternalRoomState } from '../engine/battle.types';
import type { InternalCard } from '../questions/question.types';
import type { MatchLogRpcEntry } from '../logs/match-log.types';

/** Helper to create a finished room state for testing */
function createFinishedRoom(overrides: Partial<{
  roomId: string;
  playerAUserId: string;
  playerBUserId: string;
  winnerUserId: string | null;
  loserUserId: string | null;
  reason: 'hp_zero' | 'surrender' | 'question_exhaustion' | 'draw';
  outcome: 'win' | 'lose' | 'draw' | 'surrender';
  playerAHp: number;
  playerBHp: number;
}> = {}): InternalRoomState {
  const playerAUserId = overrides.playerAUserId ?? 'user-a';
  const playerBUserId = overrides.playerBUserId ?? 'user-b';

  return {
    roomId: overrides.roomId ?? 'room_test',
    status: 'finished',
    sharedQueue: [],
    reserveQueue: [],
    nextRecycleId: 1,
    startedAt: new Date('2026-07-01T00:00:00Z'),
    endedAt: new Date('2026-07-01T00:05:00Z'),
    players: {
      playerA: {
        userId: playerAUserId,
        socketId: 'socket-a',
        role: 'playerA',
        hp: overrides.playerAHp ?? 80,
        points: 20,
        hand: [],
        answeredCardIds: new Set(),
        nextDrawIndex: 0,
        connected: true,
      },
      playerB: {
        userId: playerBUserId,
        socketId: 'socket-b',
        role: 'playerB',
        hp: overrides.playerBHp ?? 0,
        points: 10,
        hand: [],
        answeredCardIds: new Set(),
        nextDrawIndex: 0,
        connected: true,
      },
    },
    result: {
      roomId: overrides.roomId ?? 'room_test',
      outcome: overrides.outcome ?? 'win',
      winnerUserId: overrides.winnerUserId !== undefined ? overrides.winnerUserId : playerAUserId,
      loserUserId: overrides.loserUserId !== undefined ? overrides.loserUserId : playerBUserId,
      reason: overrides.reason ?? 'hp_zero',
      finalState: {
        playerA: { userId: playerAUserId, hp: overrides.playerAHp ?? 80, points: 20 },
        playerB: { userId: playerBUserId, hp: overrides.playerBHp ?? 0, points: 10 },
      },
    },
  };
}

describe('MatchResultService', () => {
  let service: MatchResultService;
  let mockRpc: jest.Mock;
  let mockInsert: jest.Mock;
  let mockAdminClient: Record<string, unknown>;

  beforeEach(async () => {
    mockRpc = jest.fn().mockResolvedValue({
      data: {
        persisted: true,
        matchResultId: 'result-123',
        ratingDeltaA: 20,
        ratingDeltaB: -12,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
      },
      error: null,
    });

    mockInsert = jest.fn().mockResolvedValue({ error: null });

    mockAdminClient = {
      rpc: mockRpc,
      from: jest.fn().mockReturnValue({ insert: mockInsert }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MatchResultService,
        {
          provide: SupabaseService,
          useValue: {
            getAdminClient: () => mockAdminClient,
          },
        },
      ],
    }).compile();

    service = module.get<MatchResultService>(MatchResultService);
    jest.spyOn(service as any, 'delay').mockResolvedValue(undefined);
  });

  describe('finalizeMatch', () => {
    it('calls RPC with correct params and returns deltas on success', async () => {
      const room = createFinishedRoom();

      const deltas = await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith('finalize_match_result', expect.objectContaining({
        p_room_id: 'room_test',
        p_mode: 'player',
        p_player_a_id: 'user-a',
        p_player_b_id: 'user-b',
        p_winner_user_id: 'user-a',
        p_loser_user_id: 'user-b',
        p_outcome: 'player_a_win',
        p_reason: 'hp_zero',
        p_player_a_hp: 80,
        p_player_b_hp: 0,
        p_player_a_points: 20,
        p_player_b_points: 10,
        p_duration_seconds: 300,
        p_started_at: expect.any(String),
      }));

      expect(deltas).toEqual({
        ratingDeltaA: 20,
        ratingDeltaB: -12,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
      });
    });

    it('returns null if room has no result', async () => {
      const room = createFinishedRoom();
      room.result = undefined;

      const deltas = await service.finalizeMatch(room);

      expect(deltas).toBeNull();
      expect(mockRpc).not.toHaveBeenCalled();
    });

    it('retries once on RPC failure, returns deltas on second success', async () => {
      mockRpc
        .mockResolvedValueOnce({ data: null, error: { message: 'transient error' } })
        .mockResolvedValueOnce({
          data: {
            persisted: true,
            matchResultId: 'result-456',
            ratingDeltaA: 20,
            ratingDeltaB: -12,
            coinsDeltaA: 10,
            coinsDeltaB: 3,
          },
          error: null,
        });

      const room = createFinishedRoom();
      const deltas = await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledTimes(2);
      expect(deltas).toEqual({
        ratingDeltaA: 20,
        ratingDeltaB: -12,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
      });
    });

    it('returns the original authoritative deltas for a duplicate result', async () => {
      mockRpc.mockResolvedValue({
        data: {
          persisted: false,
          reason: 'duplicate',
          matchResultId: 'result-123',
          ratingDeltaA: 20,
          ratingDeltaB: -12,
          coinsDeltaA: 10,
          coinsDeltaB: 3,
        },
        error: null,
      });

      await expect(service.finalizeMatch(createFinishedRoom())).resolves.toEqual({
        ratingDeltaA: 20,
        ratingDeltaB: -12,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
      });
      expect(mockRpc).toHaveBeenCalledTimes(1);
    });

    it('returns null if both RPC attempts fail', async () => {
      mockRpc.mockResolvedValue({ data: null, error: { message: 'persistent error' } });

      const room = createFinishedRoom();
      const deltas = await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledTimes(2);
      expect(deltas).toBeNull();
    });

    it('sets p_mode=bot and p_player_b_id=null for bot matches', async () => {
      const room = createFinishedRoom({
        playerBUserId: 'bot',
        winnerUserId: 'user-a',
        loserUserId: 'bot',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith('finalize_match_result', expect.objectContaining({
        p_mode: 'bot',
        p_player_b_id: null,
        p_loser_user_id: null,
      }));
    });

    it('sanitizes bot as winner (p_winner_user_id=null)', async () => {
      const room = createFinishedRoom({
        playerBUserId: 'bot',
        winnerUserId: 'bot',
        loserUserId: 'user-a',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith('finalize_match_result', expect.objectContaining({
        p_winner_user_id: null,
        p_loser_user_id: 'user-a',
      }));
    });

    it('maps outcome correctly for player_b_win', async () => {
      const room = createFinishedRoom({
        winnerUserId: 'user-b',
        loserUserId: 'user-a',
        outcome: 'win',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith('finalize_match_result', expect.objectContaining({
        p_outcome: 'player_b_win',
      }));
    });

    it('maps outcome correctly for draw', async () => {
      const room = createFinishedRoom({
        winnerUserId: null,
        loserUserId: null,
        reason: 'draw',
        outcome: 'draw',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith('finalize_match_result', expect.objectContaining({
        p_outcome: 'draw',
        p_reason: 'draw',
      }));
    });
  });

  describe('log persistence', () => {
    it('bulk-inserts logs after successful RPC', async () => {
      const room = createFinishedRoom();
      const logEntries: MatchLogRpcEntry[] = [
        { user_id: 'user-a', action: 'open_card', payload: { cardId: 'c1' }, created_at: '2026-07-01T00:00:01Z' },
        { user_id: 'user-a', action: 'play_card', payload: { cardId: 'c1' }, created_at: '2026-07-01T00:00:05Z' },
      ];

      await service.finalizeMatch(room, logEntries);

      expect(mockInsert).toHaveBeenCalledWith([
        expect.objectContaining({ match_id: 'result-123', user_id: 'user-a', action: 'open_card' }),
        expect.objectContaining({ match_id: 'result-123', user_id: 'user-a', action: 'play_card' }),
      ]);
    });

    it('skips log persistence if no matchResultId', async () => {
      mockRpc.mockResolvedValue({
        data: { persisted: false },
        error: null,
      });

      const room = createFinishedRoom();
      const logEntries: MatchLogRpcEntry[] = [
        { user_id: 'user-a', action: 'open_card', payload: {}, created_at: '2026-07-01T00:00:01Z' },
      ];

      await service.finalizeMatch(room, logEntries);

      expect(mockInsert).not.toHaveBeenCalled();
    });

    it('skips log persistence if entries array is empty', async () => {
      const room = createFinishedRoom();

      await service.finalizeMatch(room, []);

      expect(mockInsert).not.toHaveBeenCalled();
    });
  });
});
