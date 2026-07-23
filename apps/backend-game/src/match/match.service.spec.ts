import { Test, TestingModule } from '@nestjs/testing';
import { MatchService } from './match.service';
import { GameEngine } from './engine/game-engine';
import { QuestionDealer } from './engine/question-dealer';
import { QuestionService } from './questions/question.service';
import { MatchResultService } from './results/match-result.service';
import { RoomManager } from './rooms/room-manager';
import { MatchLogBuffer } from './logs/match-log-buffer';
import { BotBattleService } from './bot/bot-battle.service';
import { CardTimeoutService } from './timeout/card-timeout.service';
import { SupabaseService } from '../supabase/supabase.service';
import type { InternalCard } from './questions/question.types';
import { SERVER_MATCH_EVENTS } from '../../../../contracts/match.events';
import { GamePlayerProfileService } from './profiles/game-player-profile.service';

/** Stub cards for testing — mimics DB-sourced values */
const STUB_CARDS: InternalCard[] = Array.from({ length: 12 }, (_, i) => ({
      id: `card_${i + 1}`,
      sourceQuestionId: `question_${i + 1}`,
  prompt: `Question ${i + 1}`,
  options: ['A', 'B', 'C', 'D'],
  correctOptionIndex: 0,
  weight: 1,
  effect: i % 3 === 0 ? ('heal' as const) : ('damage' as const),
  damageValue: i % 3 === 0 ? 0 : 14,
  healValue: i % 3 === 0 ? 14 : 0,
  timeLimitSeconds: 30,
}));

const mockMatchResultService = {
  finalizeMatch: jest.fn().mockResolvedValue({
    ratingDeltaA: 20,
    ratingDeltaB: -12,
    coinsDeltaA: 10,
    coinsDeltaB: 3,
    progressionApplied: true,
  }),
};

const mockQuestionService = {
  getMatchQuestionPool: jest.fn().mockResolvedValue(STUB_CARDS),
  getMatchQuestionPoolWithReserve: jest
    .fn()
    .mockResolvedValue({ active: STUB_CARDS, reserve: [] }),
};

const mockBotBattleService = {
  createBotMatch: jest.fn().mockImplementation(async (userId, socketId) => {
    // Return a fake bot room
    const engine = new GameEngine();
    const dealer = new QuestionDealer();
    const room = engine.createRoom(
      'room_bot_test',
      userId,
      'bot',
      dealer.createSharedQueue(STUB_CARDS),
    );
    room.players.playerA.socketId = socketId;
    room.players.playerB.socketId = null;
    room.players.playerB.connected = true;
    return room;
  }),
  cancelBotSchedule: jest.fn(),
  isBotMatch: jest
    .fn()
    .mockImplementation((room) => room?.players?.playerB?.userId === 'bot'),
  setEmitCallback: jest.fn(),
  setRoundBreakCallback: jest.fn(),
  resumeBotSchedule: jest.fn(),
};

const mockSupabaseService = {
  getClient: jest.fn(),
  getAdminClient: jest.fn(),
};

const profileFor = (userId: string) => ({
  userId,
  displayName: userId,
  target: 'cpns' as const,
  loadout: {
    characterId: 'character-basic-squire',
    towerId: 'tower-garda-biru',
  },
});

const mockProfileService = {
  getProfile: jest.fn().mockImplementation(async (userId: string) =>
    profileFor(userId)),
  botProfile: jest.fn().mockImplementation(() => ({
    ...profileFor('bot'),
    displayName: 'BOT YUDHA',
  })),
};

describe('MatchService', () => {
  let service: MatchService;
  let roomManager: RoomManager;
  let cardTimeoutService: CardTimeoutService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MatchService,
        GameEngine,
        QuestionDealer,
        RoomManager,
        MatchLogBuffer,
        CardTimeoutService,
        { provide: QuestionService, useValue: mockQuestionService },
        { provide: MatchResultService, useValue: mockMatchResultService },
        { provide: BotBattleService, useValue: mockBotBattleService },
        { provide: SupabaseService, useValue: mockSupabaseService },
        { provide: GamePlayerProfileService, useValue: mockProfileService },
      ],
    }).compile();

    service = module.get<MatchService>(MatchService);
    roomManager = module.get<RoomManager>(RoomManager);
    cardTimeoutService = module.get<CardTimeoutService>(CardTimeoutService);

    mockBotBattleService.createBotMatch.mockImplementation(async (profile, socketId) => {
      return roomManager.createBotRoom(
        profile,
        mockProfileService.botProfile(),
        socketId,
        STUB_CARDS,
      );
    });

    jest
      .spyOn(cardTimeoutService, 'scheduleTimeout')
      .mockImplementation(() => {});
    jest.spyOn(cardTimeoutService, 'clearTimeout').mockImplementation(() => {});
    jest
      .spyOn(cardTimeoutService, 'cancelAllTimersForRoom')
      .mockImplementation(() => {});
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('Matchmaking Queue', () => {
    it('rejects unsupported matchmaking modes before loading a profile', async () => {
      const result = await service.handleJoinQueue(
        'player-a',
        'socket-a',
        { mode: 'tournament' as never },
      );

      expect(
        result.emits.some(
          (emit) => emit.event === SERVER_MATCH_EVENTS.error,
        ),
      ).toBe(true);
      expect(mockProfileService.getProfile).not.toHaveBeenCalled();
    });

    it('pairs two queued players and emits initial player-relative state', async () => {
      service.registerSocket('socket-a', 'player-a');
      service.registerSocket('socket-b', 'player-b');

      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
      const result = await service.handleJoinQueue('player-b', 'socket-b', {
        mode: 'casual',
      });

      expect(
        result.emits.some(
          (emit) => emit.event === SERVER_MATCH_EVENTS.matchFound,
        ),
      ).toBe(true);
      const stateEmits = result.emits.filter(
        (emit) => emit.event === SERVER_MATCH_EVENTS.gameStateUpdate,
      );
      expect(stateEmits).toHaveLength(2);
      expect(stateEmits[0].payload).toHaveProperty('self');
      expect(stateEmits[0].payload).toHaveProperty('opponent');
    });

    it('rejects active-room user joining queue again', async () => {
      service.registerSocket('socket-a', 'player-a');
      service.registerSocket('socket-b', 'player-b');
      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
      await service.handleJoinQueue('player-b', 'socket-b', { mode: 'casual' });

      const result = await service.handleJoinQueue('player-a', 'socket-a', {
        mode: 'casual',
      });

      expect(result.emits[0].event).toBe(SERVER_MATCH_EVENTS.error);
    });

    it('handles queue cancellation', async () => {
      service.registerSocket('socket-a', 'player-a');
      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });

      const result = service.handleCancelQueue('player-a', 'socket-a');
      expect(result.emits).toHaveLength(1);
      expect(result.emits[0].event).toBe(SERVER_MATCH_EVENTS.queueCancelled);
    });
  });

  describe('Bot Mode', () => {
    it('bypasses the matchmaking queue and starts a match instantly', async () => {
      service.registerSocket('socket-a', 'player-a');

      const result = await service.handleJoinQueue('player-a', 'socket-a', {
        mode: 'bot',
      });

      expect(mockBotBattleService.createBotMatch).toHaveBeenCalledWith(
        profileFor('player-a'),
        'socket-a',
      );
      expect(result.emits.some((emit) => emit.event === SERVER_MATCH_EVENTS.matchFound)).toBe(true);
      expect(result.emits.some((emit) => emit.event === SERVER_MATCH_EVENTS.gameStateUpdate)).toBe(true);
        'player-a',
        'socket-a',
      );
      expect(
        result.emits.some(
          (emit) => emit.event === SERVER_MATCH_EVENTS.matchFound,
        ),
      ).toBe(true);
      expect(
        result.emits.some(
          (emit) => emit.event === SERVER_MATCH_EVENTS.gameStateUpdate,
        ),
      ).toBe(true);
    });

    it('rejects bot mode join if player is already in an active room', async () => {
      service.registerSocket('socket-a', 'player-a');
      service.registerSocket('socket-b', 'player-b');
      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
      await service.handleJoinQueue('player-b', 'socket-b', { mode: 'casual' });

      const result = await service.handleJoinQueue('player-a', 'socket-a', {
        mode: 'bot',
      });
      expect(result.emits[0].event).toBe(SERVER_MATCH_EVENTS.error);
    });
  });

  describe('In-Game Actions', () => {
    let roomId: string;

    beforeEach(async () => {
      service.registerSocket('socket-a', 'player-a');
      service.registerSocket('socket-b', 'player-b');
      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
      const joinResult = await service.handleJoinQueue('player-b', 'socket-b', {
        mode: 'casual',
      });
      const matchFoundEmit = joinResult.emits.find(
        (e) => e.event === SERVER_MATCH_EVENTS.matchFound,
      );
      roomId = (matchFoundEmit?.payload as any).roomId;
    });

    it('handles open_card successfully and schedules turn timeout', () => {
      const result = service.handleOpenCard('player-a', 'socket-a', {
        roomId,
        cardId: 'card_1',
      });

      expect(
        result.emits.some(
          (e) => e.event === SERVER_MATCH_EVENTS.openCardAccepted,
        ),
      ).toBe(true);
      expect(cardTimeoutService.scheduleTimeout).toHaveBeenCalledWith(
        roomId,
        'player-a',
        'card_1',
        expect.any(Number),
        expect.any(Function),
      );
    });

    it('rejects open_card if room is not found', () => {
      const result = service.handleOpenCard('player-a', 'socket-a', {
        roomId: 'invalid-room',
        cardId: 'card_1',
      });
      expect(result.emits[0].event).toBe(
        SERVER_MATCH_EVENTS.cardActionRejected,
      );
    });

    it('handles play_card successfully and clears timeout', async () => {
      service.handleOpenCard('player-a', 'socket-a', {
        roomId,
        cardId: 'card_1',
      });

      const result = await service.handlePlayCard('player-a', 'socket-a', {
        roomId,
        cardId: 'card_1',
        selectedOptionIndex: 0,
      });

      expect(cardTimeoutService.clearTimeout).toHaveBeenCalledWith(
        roomId,
        'player-a',
      );
      expect(
        result.emits.some(
          (e) => e.event === SERVER_MATCH_EVENTS.playCardResult,
        ),
      ).toBe(true);
    });

    it('handles play_card incorrect answer and updates state', async () => {
      service.handleOpenCard('player-a', 'socket-a', {
        roomId,
        cardId: 'card_1',
      });

      const result = await service.handlePlayCard('player-a', 'socket-a', {
        roomId,
        cardId: 'card_1',
        selectedOptionIndex: 1, // incorrect
      });

      const playResultEmit = result.emits.find(
        (e) => e.event === SERVER_MATCH_EVENTS.playCardResult,
      );
      expect((playResultEmit?.payload as any).correct).toBe(false);
    });

    it('handles surrender and cleans up room/timers', async () => {
      const result = await service.handleSurrender('player-a', 'socket-a', {
        roomId,
      });

      expect(cardTimeoutService.cancelAllTimersForRoom).toHaveBeenCalledWith(roomId);
      expect(mockBotBattleService.cancelBotSchedule).toHaveBeenCalledWith(roomId);
      const resultEmit = result.emits.find(
        (emit) => emit.event === SERVER_MATCH_EVENTS.matchResult,
      );
      expect(resultEmit).toBeDefined();
      expect((resultEmit?.payload as { progressionPersisted?: boolean }).progressionPersisted).toBe(
        true,
      );
    });

    it('rejects surrender if room not found', async () => {
      const result = await service.handleSurrender('player-a', 'socket-a', {
        roomId: 'invalid-room',
      });
      expect(result.emits[0].event).toBe(SERVER_MATCH_EVENTS.error);
    });
  });

  describe('Card Timeout Event Handler', () => {
    let roomId: string;

    beforeEach(async () => {
      service.registerSocket('socket-a', 'player-a');
      service.registerSocket('socket-b', 'player-b');
      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
      const joinResult = await service.handleJoinQueue('player-b', 'socket-b', {
        mode: 'casual',
      });
      const matchFoundEmit = joinResult.emits.find(
        (e) => e.event === SERVER_MATCH_EVENTS.matchFound,
      );
      roomId = (matchFoundEmit?.payload as any).roomId;

      service.handleOpenCard('player-a', 'socket-a', {
        roomId,
        cardId: 'card_1',
      });
    });

    it('processes card timeout, fires playCardResult with correct=false, and notifies client', async () => {
      const emitServerSpy = jest.fn();
      service.setEmitServer(emitServerSpy);

      await service.handleCardTimeout(roomId, 'player-a', 'card_1');

      expect(emitServerSpy).toHaveBeenCalled();
      const emitted = emitServerSpy.mock.calls[0][0];
      const resultEmit = emitted.emits.find(
        (e: any) => e.event === SERVER_MATCH_EVENTS.playCardResult,
      );
      expect(resultEmit).toBeDefined();
      expect(resultEmit.payload.correct).toBe(false);
    });
  });

  describe('Disconnect Handling', () => {
    async function createCasualMatch() {
      service.registerSocket('socket-a', 'player-a');
      service.registerSocket('socket-b', 'player-b');
      await service.handleJoinQueue('player-a', 'socket-a', {
        mode: 'casual',
      });
      const joinResult = await service.handleJoinQueue(
        'player-b',
        'socket-b',
        { mode: 'casual' },
      );
      const matchFound = joinResult.emits.find(
        (emit) => emit.event === SERVER_MATCH_EVENTS.matchFound,
      );
      const roomId = (matchFound!.payload as { roomId: string }).roomId;
      return { roomId, room: roomManager.getRoom(roomId)! };
    }

    it('restores current state when the player reconnects before 30 seconds', async () => {
      jest.useFakeTimers();
      try {
        const { room } = await createCasualMatch();
        const disconnected = service.handleDisconnect('socket-a');
        const presence = disconnected.emits.find(
          (emit) => emit.event === SERVER_MATCH_EVENTS.presenceUpdate,
        )!.payload as {
          players: Record<
            string,
            { connected: boolean; reconnectDeadline?: string }
          >;
        };

        expect(presence.players['player-a'].connected).toBe(false);
        expect(presence.players['player-a'].reconnectDeadline).toBeDefined();

        const reconnect = service.registerSocket('socket-a-new', 'player-a');
        await jest.advanceTimersByTimeAsync(
          MatchService.DISCONNECT_GRACE_MS,
        );

        expect(room.status).toBe('active');
        expect(room.players.playerA.connected).toBe(true);
        expect(room.players.playerA.reconnectDeadline).toBeUndefined();
        expect(
          reconnect.emits.some(
            (emit) => emit.event === SERVER_MATCH_EVENTS.gameStateUpdate,
          ),
        ).toBe(true);
        expect(mockMatchResultService.finalizeMatch).not.toHaveBeenCalled();
      } finally {
        jest.clearAllTimers();
        jest.useRealTimers();
      }
    });

    it('awards the connected opponent a disconnect win after 30 seconds', async () => {
      jest.useFakeTimers();
      try {
        const emitServer = jest.fn();
        service.setEmitServer(emitServer);
        const { room } = await createCasualMatch();

        service.handleDisconnect('socket-a');
        await jest.advanceTimersByTimeAsync(
          MatchService.DISCONNECT_GRACE_MS,
        );

        expect(room.status).toBe('finished');
        expect(room.result?.reason).toBe('disconnect');
        expect(room.result?.winnerUserId).toBe('player-b');
        expect(mockMatchResultService.finalizeMatch).toHaveBeenCalledTimes(1);
        expect(
          emitServer.mock.calls[0][0].emits.some(
            (emit: { event: string }) =>
              emit.event === SERVER_MATCH_EVENTS.matchResult,
          ),
        ).toBe(true);
      } finally {
        jest.clearAllTimers();
        jest.useRealTimers();
      }
    });

    it('persists an abandoned zero-progression draw when both players stay offline', async () => {
      jest.useFakeTimers();
      try {
        mockMatchResultService.finalizeMatch.mockResolvedValueOnce({
          ratingDeltaA: 0,
          ratingDeltaB: 0,
          coinsDeltaA: 0,
          coinsDeltaB: 0,
          progressionApplied: false,
        });
        const { room } = await createCasualMatch();

        service.handleDisconnect('socket-a');
        service.handleDisconnect('socket-b');
        await jest.advanceTimersByTimeAsync(
          MatchService.DISCONNECT_GRACE_MS,
        );

        expect(room.status).toBe('finished');
        expect(room.result?.reason).toBe('disconnect');
        expect(room.result?.outcome).toBe('draw');
        expect(room.result?.winnerUserId).toBeNull();
        expect(room.result?.loserUserId).toBeNull();
        expect(room.result?.progressionPersisted).toBe(false);
        expect(mockMatchResultService.finalizeMatch).toHaveBeenCalledTimes(1);
      } finally {
        jest.clearAllTimers();
        jest.useRealTimers();
      }
    });

    it('clears the disconnect forfeit when normal match completion wins first', async () => {
      jest.useFakeTimers();
      try {
        const { roomId, room } = await createCasualMatch();
        service.handleDisconnect('socket-a');
        room.players.playerA.hp = 10;

        service.handleOpenCard('player-b', 'socket-b', {
          roomId,
          cardId: 'card_2',
        });
        await service.handlePlayCard('player-b', 'socket-b', {
          roomId,
          cardId: 'card_2',
          selectedOptionIndex: 0,
        });
        await jest.advanceTimersByTimeAsync(
          MatchService.DISCONNECT_GRACE_MS,
        );

        expect(room.result?.reason).toBe('hp_zero');
        expect(mockMatchResultService.finalizeMatch).toHaveBeenCalledTimes(1);
      } finally {
        jest.clearAllTimers();
        jest.useRealTimers();
      }
    });

    it('keeps match timers running during the reconnect grace period', async () => {
      service.registerSocket('socket-a', 'player-a');
      service.registerSocket('socket-b', 'player-b');
      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
      const joinResult = await service.handleJoinQueue('player-b', 'socket-b', {
        mode: 'casual',
      });
      const matchFoundEmit = joinResult.emits.find(
        (e) => e.event === SERVER_MATCH_EVENTS.matchFound,
      );
      const roomId = (matchFoundEmit?.payload as any).roomId;

      const result = service.handleDisconnect('socket-a');

      expect(cardTimeoutService.cancelAllTimersForRoom).not.toHaveBeenCalledWith(roomId);
      expect(result.emits.some((e) => e.event === SERVER_MATCH_EVENTS.presenceUpdate)).toBe(true);
    });

    it('returns empty emits if disconnecting user is only queue-removed', async () => {
      service.registerSocket('socket-a', 'player-a');
      await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });

      const result = service.handleDisconnect('socket-a');
      expect(result.emits).toEqual([]);
    });
  });
});
