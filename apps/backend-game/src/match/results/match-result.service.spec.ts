import { Test, TestingModule } from '@nestjs/testing';
import { MatchResultService } from './match-result.service';
import { SupabaseService } from '../../supabase/supabase.service';
import type { InternalRoomState } from '../engine/battle.types';
import type { MatchLogRpcEntry } from '../logs/match-log.types';

/** Helper to create a finished room state for testing */
function createFinishedRoom(
  overrides: Partial<{
    roomId: string;
    playerAUserId: string;
    playerBUserId: string;
    mode: 'ranked' | 'casual' | 'bot' | 'private';
    winnerUserId: string | null;
    loserUserId: string | null;
    reason: 'hp_zero' | 'surrender' | 'disconnect' | 'draw';
    outcome: 'win' | 'lose' | 'draw' | 'surrender';
    playerAHp: number;
    playerBHp: number;
  }> = {},
): InternalRoomState {
  const playerAUserId = overrides.playerAUserId ?? 'user-a';
  const playerBUserId = overrides.playerBUserId ?? 'user-b';

  return {
    roomId: overrides.roomId ?? 'room_test',
    status: 'finished',
    mode: overrides.mode ?? (playerBUserId === 'bot' ? 'bot' : 'ranked'),
    target: 'cpns',
    sharedQueue: [],
    reserveQueue: [],
    nextRecycleId: 1,
    currentRound: 1,
    playerARoundWins: 0,
    playerBRoundWins: 0,
    roundStatus: 'active',
    startedAt: new Date('2026-07-01T00:00:00Z'),
    endedAt: new Date('2026-07-01T00:05:00Z'),
    players: {
      playerA: {
        userId: playerAUserId,
        displayName: 'User A',
        loadout: {
          characterId: 'character-basic-squire',
          towerId: 'tower-garda-biru',
        },
        socketId: 'socket-a',
        role: 'playerA',
        hp: overrides.playerAHp ?? 80,
        points: 20,
        comboLevel: 0,
        hand: [],
        answeredCardIds: new Set(),
        connected: true,
      },
      playerB: {
        userId: playerBUserId,
        displayName: 'User B',
        loadout: {
          characterId: 'character-basic-pip',
          towerId: 'tower-benteng-bara',
        },
        socketId: 'socket-b',
        role: 'playerB',
        hp: overrides.playerBHp ?? 0,
        points: 10,
        comboLevel: 0,
        hand: [],
        answeredCardIds: new Set(),
        connected: true,
      },
    },
    result: {
      roomId: overrides.roomId ?? 'room_test',
      mode: overrides.mode ?? (playerBUserId === 'bot' ? 'bot' : 'ranked'),
      target: 'cpns',
      outcome: overrides.outcome ?? 'win',
      winnerUserId:
        overrides.winnerUserId !== undefined
          ? overrides.winnerUserId
          : playerAUserId,
      loserUserId:
        overrides.loserUserId !== undefined
          ? overrides.loserUserId
          : playerBUserId,
      reason: overrides.reason ?? 'hp_zero',
      finalState: {
        playerA: {
          userId: playerAUserId,
          hp: overrides.playerAHp ?? 80,
          points: 20,
        },
        playerB: {
          userId: playerBUserId,
          hp: overrides.playerBHp ?? 0,
          points: 10,
        },
      },
    },
  };
}

describe('MatchResultService', () => {
  let service: MatchResultService;
  let mockRpc: jest.Mock;
  let mockInsert: jest.Mock;
  let mockAdminClient: Record<string, unknown>;
  const originalLearningV2Enabled = process.env.LEARNING_V2_ENABLED;

  beforeEach(async () => {
    process.env.LEARNING_V2_ENABLED = 'false';
    mockRpc = jest.fn().mockResolvedValue({
      data: {
        persisted: true,
        matchResultId: 'result-123',
        pvpRatingDeltaA: 20,
        pvpRatingDeltaB: -12,
        pvpRatingAfterA: 1020,
        pvpRatingAfterB: 988,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
        energyDeltaA: 1,
        energyDeltaB: 1,
        energyBalanceAfterA: 9,
        energyBalanceAfterB: 9,
        progressionApplied: true,
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

  afterAll(() => {
    if (originalLearningV2Enabled === undefined) {
      delete process.env.LEARNING_V2_ENABLED;
    } else {
      process.env.LEARNING_V2_ENABLED = originalLearningV2Enabled;
    }
  });

  describe('finalizeMatch', () => {
    it('calls RPC with correct params and returns deltas on success', async () => {
      const room = createFinishedRoom();

      const deltas = await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_room_id: 'room_test',
          p_mode: 'ranked',
          p_target: 'cpns',
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
        }),
      );

      expect(deltas).toEqual({
        pvpRatingDeltaA: 20,
        pvpRatingDeltaB: -12,
        pvpRatingAfterA: 1020,
        pvpRatingAfterB: 988,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
        energyDeltaA: 1,
        energyDeltaB: 1,
        energyBalanceAfterA: 9,
        energyBalanceAfterB: 9,
        progressionApplied: true,
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
        .mockResolvedValueOnce({
          data: null,
          error: { message: 'transient error' },
        })
        .mockResolvedValueOnce({
          data: {
            persisted: true,
            matchResultId: 'result-456',
            pvpRatingDeltaA: 20,
            pvpRatingDeltaB: -12,
            pvpRatingAfterA: 1020,
            pvpRatingAfterB: 988,
            coinsDeltaA: 10,
            coinsDeltaB: 3,
            energyDeltaA: 1,
            energyDeltaB: 1,
            energyBalanceAfterA: 9,
            energyBalanceAfterB: 9,
            progressionApplied: true,
          },
          error: null,
        });

      const room = createFinishedRoom();
      const deltas = await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledTimes(2);
      expect(deltas).toEqual({
        pvpRatingDeltaA: 20,
        pvpRatingDeltaB: -12,
        pvpRatingAfterA: 1020,
        pvpRatingAfterB: 988,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
        energyDeltaA: 1,
        energyDeltaB: 1,
        energyBalanceAfterA: 9,
        energyBalanceAfterB: 9,
        progressionApplied: true,
      });
    });

    it('returns the original authoritative deltas for a duplicate result', async () => {
      mockRpc.mockResolvedValue({
        data: {
          persisted: false,
          reason: 'duplicate',
          matchResultId: 'result-123',
          pvpRatingDeltaA: 20,
          pvpRatingDeltaB: -12,
          pvpRatingAfterA: 1020,
          pvpRatingAfterB: 988,
          coinsDeltaA: 10,
          coinsDeltaB: 3,
          energyDeltaA: 1,
          energyDeltaB: 1,
          energyBalanceAfterA: 9,
          energyBalanceAfterB: 9,
          progressionApplied: true,
        },
        error: null,
      });

      await expect(
        service.finalizeMatch(createFinishedRoom()),
      ).resolves.toEqual({
        pvpRatingDeltaA: 20,
        pvpRatingDeltaB: -12,
        pvpRatingAfterA: 1020,
        pvpRatingAfterB: 988,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
        energyDeltaA: 1,
        energyDeltaB: 1,
        energyBalanceAfterA: 9,
        energyBalanceAfterB: 9,
        progressionApplied: true,
      });
      expect(mockRpc).toHaveBeenCalledTimes(1);
    });

    it('returns null if both RPC attempts fail', async () => {
      mockRpc.mockResolvedValue({
        data: null,
        error: { message: 'persistent error' },
      });

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

      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_mode: 'bot',
          p_player_b_id: null,
          p_loser_user_id: null,
        }),
      );
    });

    it('preserves zero-delta casual history without progression', async () => {
      mockRpc.mockResolvedValue({
        data: {
          persisted: true,
          matchResultId: 'casual-result',
          ratingDeltaA: 0,
          ratingDeltaB: 0,
          coinsDeltaA: 0,
          coinsDeltaB: 0,
          progressionApplied: false,
        },
        error: null,
      });
      const room = createFinishedRoom({ mode: 'casual' });

      await expect(service.finalizeMatch(room)).resolves.toEqual({
        pvpRatingDeltaA: null,
        pvpRatingDeltaB: null,
        pvpRatingAfterA: null,
        pvpRatingAfterB: null,
        coinsDeltaA: 0,
        coinsDeltaB: 0,
        energyDeltaA: undefined,
        energyDeltaB: undefined,
        energyBalanceAfterA: undefined,
        energyBalanceAfterB: undefined,
        progressionApplied: false,
      });
      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_mode: 'casual',
          p_target: 'cpns',
        }),
      );
    });

    it('persists Private history with both human players and zero progression', async () => {
      mockRpc.mockResolvedValue({
        data: {
          persisted: true,
          matchResultId: 'private-result',
          pvpRatingDeltaA: null,
          pvpRatingDeltaB: null,
          pvpRatingAfterA: null,
          pvpRatingAfterB: null,
          coinsDeltaA: 0,
          coinsDeltaB: 0,
          progressionApplied: false,
        },
        error: null,
      });
      const room = createFinishedRoom({ mode: 'private' });

      await expect(service.finalizeMatch(room)).resolves.toEqual({
        pvpRatingDeltaA: null,
        pvpRatingDeltaB: null,
        pvpRatingAfterA: null,
        pvpRatingAfterB: null,
        coinsDeltaA: 0,
        coinsDeltaB: 0,
        energyDeltaA: undefined,
        energyDeltaB: undefined,
        energyBalanceAfterA: undefined,
        energyBalanceAfterB: undefined,
        progressionApplied: false,
      });
      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_mode: 'private',
          p_player_a_id: 'user-a',
          p_player_b_id: 'user-b',
        }),
      );
    });

    it('persists both-offline disconnect as an abandoned draw', async () => {
      const room = createFinishedRoom({
        mode: 'ranked',
        winnerUserId: null,
        loserUserId: null,
        outcome: 'draw',
        reason: 'disconnect',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_mode: 'ranked',
          p_winner_user_id: null,
          p_loser_user_id: null,
          p_outcome: 'draw',
          p_reason: 'disconnect',
        }),
      );
    });

    it('sanitizes bot as winner (p_winner_user_id=null)', async () => {
      const room = createFinishedRoom({
        playerBUserId: 'bot',
        winnerUserId: 'bot',
        loserUserId: 'user-a',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_winner_user_id: null,
          p_loser_user_id: 'user-a',
        }),
      );
    });

    it('maps outcome correctly for player_b_win', async () => {
      const room = createFinishedRoom({
        winnerUserId: 'user-b',
        loserUserId: 'user-a',
        outcome: 'win',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_outcome: 'player_b_win',
        }),
      );
    });

    it('maps outcome correctly for draw', async () => {
      const room = createFinishedRoom({
        winnerUserId: null,
        loserUserId: null,
        reason: 'draw',
        outcome: 'draw',
      });

      await service.finalizeMatch(room);

      expect(mockRpc).toHaveBeenCalledWith(
        'finalize_match_result',
        expect.objectContaining({
          p_outcome: 'draw',
          p_reason: 'draw',
        }),
      );
    });
  });

  describe('log persistence', () => {
    it('bulk-inserts logs after successful RPC', async () => {
      const room = createFinishedRoom();
      const logEntries: MatchLogRpcEntry[] = [
        {
          user_id: 'user-a',
          action: 'open_card',
          payload: { cardId: 'c1' },
          created_at: '2026-07-01T00:00:01Z',
        },
        {
          user_id: 'user-a',
          action: 'play_card',
          payload: { cardId: 'c1' },
          created_at: '2026-07-01T00:00:05Z',
        },
      ];

      await service.finalizeMatch(room, logEntries);

      expect(mockInsert).toHaveBeenCalledWith([
        expect.objectContaining({
          match_result_id: 'result-123',
          player_id: 'user-a',
          action_type: 'open_card',
          card_id: 'c1',
        }),
        expect.objectContaining({
          match_result_id: 'result-123',
          player_id: 'user-a',
          action_type: 'play_card',
          card_id: 'c1',
        }),
      ]);
      expect(mockRpc).toHaveBeenCalledTimes(1);
    });

    it('ingests PvP learning evidence once when Learning V2 is enabled', async () => {
      process.env.LEARNING_V2_ENABLED = 'true';
      const room = createFinishedRoom();
      const logEntries: MatchLogRpcEntry[] = [
        {
          user_id: 'user-a',
          action: 'play_card',
          payload: {
            questionId: 'cpns-twk-001',
            selectedOptionIndex: 1,
            correct: true,
          },
          created_at: '2026-07-01T00:00:05Z',
        },
      ];

      await service.finalizeMatch(room, logEntries);

      expect(mockRpc).toHaveBeenNthCalledWith(
        2,
        'ingest_pvp_learning_evidence',
        { p_match_result_id: 'result-123' },
      );
      expect(mockRpc).toHaveBeenCalledTimes(2);
    });

    it('skips log persistence if no matchResultId', async () => {
      mockRpc.mockResolvedValue({
        data: { persisted: false },
        error: null,
      });

      const room = createFinishedRoom();
      const logEntries: MatchLogRpcEntry[] = [
        {
          user_id: 'user-a',
          action: 'open_card',
          payload: {},
          created_at: '2026-07-01T00:00:01Z',
        },
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
