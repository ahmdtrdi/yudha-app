import { SERVER_MATCH_EVENTS } from '../contracts/match.events';
import type {
  RedisPrivateReservation,
  RedisQueueEntry,
  RoomRoute,
} from '../redis/game-coordination.types';
import { GameEngine } from './engine/game-engine';
import { QuestionDealer } from './engine/question-dealer';
import type { InternalCard } from './questions/question.types';
import type { GamePlayerProfile } from './profiles/game-player-profile.service';
import { MatchLogBuffer } from './logs/match-log-buffer';
import { MatchService, type MatchServiceResult } from './match.service';
import { MatchmakingService } from './rooms/matchmaking.service';
import { RoomManager } from './rooms/room-manager';

const cards: InternalCard[] = Array.from({ length: 12 }, (_, index) => ({
  id: `card_${index + 1}`,
  sourceQuestionId: `question_${index + 1}`,
  prompt: `Question ${index + 1}`,
  options: ['A', 'B', 'C', 'D'],
  correctOptionIndex: 0,
  weight: 1,
  effect: 'damage' as const,
  damageValue: 10,
  healValue: 0,
  timeLimitSeconds: 30,
}));

const profile = (
  userId: string,
  target: 'cpns' | 'bumn' = 'cpns',
): GamePlayerProfile => ({
  userId,
  displayName: `Display ${userId}`,
  target,
  loadout: {
    characterId: 'character-basic-squire',
    towerId: 'tower-garda-biru',
  },
});

class FakeCoordination {
  available = true;
  readonly routes = new Map<string, RoomRoute>();
  readonly userRoutes = new Map<string, RoomRoute>();
  private readonly queues = new Map<string, RedisQueueEntry[]>();
  private readonly queuedUsers = new Map<string, string>();
  private readonly reservations = new Map<string, RedisPrivateReservation>();
  private readonly ownerCodes = new Map<string, string>();
  private readonly commands = new Map<
    string,
    { fingerprint: string; requestId: string; acknowledgement?: unknown }
  >();

  async joinPublicQueue(
    player: GamePlayerProfile,
    socketId: string,
    mode: 'casual' | 'ranked',
  ) {
    if (!this.available) return { type: 'unavailable' as const };
    if (
      this.queuedUsers.has(player.userId) ||
      this.userRoutes.has(player.userId)
    ) {
      return { type: 'conflict' as const };
    }
    const bucket = `${player.target}:${mode}`;
    const queue = this.queues.get(bucket) ?? [];
    const entry: RedisQueueEntry = {
      ...player,
      socketId,
      instanceId: 'instance-a',
      mode,
      joinedAt: Date.now(),
      expiresAt: Date.now() + 45_000,
    };
    const opponent = queue.shift();
    this.queues.set(bucket, queue);
    if (opponent) {
      this.queuedUsers.delete(opponent.userId);
      return { type: 'matched' as const, entry, opponent, matchId: 'match-1' };
    }
    queue.push(entry);
    this.queuedUsers.set(player.userId, bucket);
    return {
      type: 'queued' as const,
      entry,
      position: queue.length,
      depth: queue.length,
    };
  }

  async cancelPublicQueue(userId: string) {
    const bucket = this.queuedUsers.get(userId);
    if (!bucket) return false;
    this.queues.set(
      bucket,
      (this.queues.get(bucket) ?? []).filter(
        (entry) => entry.userId !== userId,
      ),
    );
    this.queuedUsers.delete(userId);
    return true;
  }

  async refreshQueue() {
    return this.available;
  }

  async restorePublicPair(entries: RedisQueueEntry[]) {
    for (const entry of entries) {
      const bucket = `${entry.target}:${entry.mode}`;
      const queue = this.queues.get(bucket) ?? [];
      queue.push(entry);
      this.queues.set(bucket, queue);
      this.queuedUsers.set(entry.userId, bucket);
    }
  }

  async createPrivateReservation(
    owner: GamePlayerProfile,
    socketId: string,
    code: string,
  ) {
    if (!this.available) return 'unavailable' as const;
    if (
      this.ownerCodes.has(owner.userId) ||
      this.queuedUsers.has(owner.userId)
    ) {
      return 'conflict' as const;
    }
    if (this.reservations.has(code)) return 'collision' as const;
    const now = Date.now();
    const reservation: RedisPrivateReservation = {
      code,
      owner: { ...owner, socketId, instanceId: 'instance-a' },
      target: owner.target,
      createdAt: now,
      expiresAt: now + 900_000,
    };
    this.reservations.set(code, reservation);
    this.ownerCodes.set(owner.userId, code);
    return 'created' as const;
  }

  async getPrivateReservation(code: string) {
    return this.available ? this.reservations.get(code) : undefined;
  }

  async getPrivateReservationForOwner(userId: string) {
    const code = this.ownerCodes.get(userId);
    return code ? this.reservations.get(code) : undefined;
  }

  async updatePrivateOwnerSocket(
    reservation: RedisPrivateReservation,
    socketId: string,
  ) {
    this.reservations.set(reservation.code, {
      ...reservation,
      owner: { ...reservation.owner, socketId },
    });
  }

  async consumePrivateReservation(joiner: GamePlayerProfile, code: string) {
    if (!this.available) return { type: 'unavailable' as const };
    const reservation = this.reservations.get(code);
    if (
      !reservation ||
      reservation.owner.userId === joiner.userId ||
      reservation.target !== joiner.target
    ) {
      return { type: 'invalid' as const };
    }
    this.reservations.delete(code);
    this.ownerCodes.delete(reservation.owner.userId);
    return { type: 'joined' as const, reservation };
  }

  async cancelPrivateReservation(userId: string, code: string) {
    const reservation = this.reservations.get(code);
    if (!reservation || reservation.owner.userId !== userId) return undefined;
    this.reservations.delete(code);
    this.ownerCodes.delete(userId);
    return reservation;
  }

  async registerRoom(route: RoomRoute) {
    if (!this.available) return false;
    this.routes.set(route.roomId, route);
    route.userIds.forEach((userId) => this.userRoutes.set(userId, route));
    return true;
  }

  async getRoomRoute(roomId: string) {
    return this.available ? this.routes.get(roomId) : undefined;
  }

  async getUserRoomRoute(userId: string) {
    return this.available ? this.userRoutes.get(userId) : undefined;
  }

  async removeRoom(route: RoomRoute) {
    this.routes.delete(route.roomId);
    route.userIds.forEach((userId) => this.userRoutes.delete(userId));
  }

  async claimCommand(userId: string, commandId: string, fingerprint: string) {
    if (!this.available)
      return { type: 'unavailable' as const, requestId: 'request-unavailable' };
    const key = `${userId}:${commandId}`;
    const existing = this.commands.get(key);
    if (existing) {
      if (existing.fingerprint !== fingerprint) {
        return { type: 'conflict' as const, requestId: existing.requestId };
      }
      if (existing.acknowledgement) {
        return {
          type: 'replay' as const,
          requestId: existing.requestId,
          acknowledgement: existing.acknowledgement,
        };
      }
      return { type: 'pending' as const, requestId: existing.requestId };
    }
    const requestId = `request-${this.commands.size + 1}`;
    this.commands.set(key, { fingerprint, requestId });
    return { type: 'claimed' as const, requestId };
  }

  async completeCommand(
    userId: string,
    commandId: string,
    fingerprint: string,
    requestId: string,
    acknowledgement: unknown,
  ) {
    this.commands.set(`${userId}:${commandId}`, {
      fingerprint,
      requestId,
      acknowledgement,
    });
  }
}

describe('MatchService distributed coordination', () => {
  let service: MatchService;
  let coordination: FakeCoordination;
  let rooms: RoomManager;
  let router: {
    setHandler: jest.Mock;
    route: jest.Mock<Promise<MatchServiceResult>, [string, unknown]>;
  };
  let questions: { getMatchQuestionPool: jest.Mock };

  beforeEach(() => {
    coordination = new FakeCoordination();
    rooms = new RoomManager(new GameEngine(), new QuestionDealer());
    router = {
      setHandler: jest.fn(),
      route: jest.fn().mockResolvedValue({ emits: [] }),
    };
    questions = {
      getMatchQuestionPool: jest.fn().mockResolvedValue(cards),
    };
    const profiles = {
      getProfile: jest.fn((userId: string) =>
        Promise.resolve(
          profile(userId, userId.startsWith('bumn') ? 'bumn' : 'cpns'),
        ),
      ),
      botProfile: jest.fn(() => ({
        ...profile('bot'),
        displayName: 'BOT YUDHA',
      })),
    };
    const botBattle = {
      createBotMatch: jest.fn(
        async (player: GamePlayerProfile, socketId: string) =>
          rooms.createBotRoom(player, profiles.botProfile(), socketId, cards),
      ),
      cancelBotSchedule: jest.fn(),
      isBotMatch: jest.fn((room) => room?.mode === 'bot'),
      setEmitCallback: jest.fn(),
      setRoundBreakCallback: jest.fn(),
      setMatchFinishedCallback: jest.fn(),
      resumeBotSchedule: jest.fn(),
    };
    const cardTimeout = {
      scheduleTimeout: jest.fn(),
      clearTimeout: jest.fn(),
      cancelAllTimersForRoom: jest.fn(),
    };
    const matchmaking = new MatchmakingService(rooms, coordination as never);

    service = new MatchService(
      new GameEngine(),
      questions as never,
      rooms,
      { finalizeMatch: jest.fn() } as never,
      new MatchLogBuffer(),
      botBattle as never,
      cardTimeout as never,
      profiles as never,
      matchmaking,
      coordination as never,
      { instanceId: 'instance-a' } as never,
      router as never,
    );
  });

  it('pairs FIFO only within the exact target and mode, then stores routing', async () => {
    await service.registerSocket('socket-a', 'player-a');
    await service.registerSocket('socket-bumn', 'bumn-player');
    await service.registerSocket('socket-b', 'player-b');

    await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
    await service.handleJoinQueue('bumn-player', 'socket-bumn', {
      mode: 'casual',
    });
    expect(questions.getMatchQuestionPool).not.toHaveBeenCalled();
    const matched = await service.handleJoinQueue('player-b', 'socket-b', {
      mode: 'casual',
    });

    expect(questions.getMatchQuestionPool).toHaveBeenCalledTimes(1);
    const found = matched.emits.find(
      (emit) => emit.event === SERVER_MATCH_EVENTS.matchFound,
    );
    expect(found).toBeDefined();
    const roomId = (found?.payload as { roomId: string }).roomId;
    expect(coordination.routes.get(roomId)).toEqual(
      expect.objectContaining({ instanceId: 'instance-a', mode: 'casual' }),
    );
  });

  it.each(['casual', 'ranked'] as const)(
    'combines both recommendation profiles for %s PvP',
    async (mode) => {
      await service.registerSocket('socket-a', 'player-a');
      await service.registerSocket('socket-b', 'player-b');
      await service.handleJoinQueue('player-a', 'socket-a', { mode });
      await service.handleJoinQueue('player-b', 'socket-b', { mode });

      expect(questions.getMatchQuestionPool).toHaveBeenCalledWith(
        'cpns',
        undefined,
        ['player-a', 'player-b'],
      );
    },
  );

  it('rejects Redis-backed matchmaking during outage but keeps Bot mode local', async () => {
    coordination.available = false;
    const unavailable = await service.handleJoinQueue('player-a', 'socket-a', {
      mode: 'casual',
    });
    const bot = await service.handleJoinQueue('player-a', 'socket-a', {
      mode: 'bot',
    });

    expect(unavailable.emits[0].payload).toEqual(
      expect.objectContaining({ code: 'QUEUE_UNAVAILABLE' }),
    );
    expect(
      bot.emits.some((emit) => emit.event === SERVER_MATCH_EVENTS.matchFound),
    ).toBe(true);
  });

  it('removes queued leases on explicit cancellation and disconnect', async () => {
    await service.registerSocket('socket-a', 'player-a');
    await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
    const cancelled = await service.handleCancelQueue('player-a', 'socket-a');
    expect(cancelled.emits[0].event).toBe(SERVER_MATCH_EVENTS.queueCancelled);

    await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
    await service.handleDisconnect('socket-a');
    const next = await service.handleJoinQueue('player-b', 'socket-b', {
      mode: 'casual',
    });
    expect(
      next.emits.some((emit) => emit.event === SERVER_MATCH_EVENTS.matchFound),
    ).toBe(false);
  });

  it('routes a battle mutation to the owning instance', async () => {
    coordination.routes.set('room-remote', {
      roomId: 'room-remote',
      instanceId: 'instance-b',
      mode: 'casual',
      userIds: ['player-a', 'player-b'],
    });
    router.route.mockResolvedValue({
      emits: [
        {
          socketId: 'socket-a',
          event: SERVER_MATCH_EVENTS.openCardAccepted,
          payload: {},
        },
      ],
    });

    const result = await service.handleOpenCard('player-a', 'socket-a', {
      roomId: 'room-remote',
      cardId: 'card_1',
    });
    await service.handlePlayCard('player-a', 'socket-a', {
      roomId: 'room-remote',
      cardId: 'card_1',
      selectedOptionIndex: 0,
    });
    await service.handleSurrender('player-a', 'socket-a', {
      roomId: 'room-remote',
    });

    expect(router.route).toHaveBeenCalledWith(
      'instance-b',
      expect.objectContaining({ operation: 'open_card', userId: 'player-a' }),
    );
    expect(router.route).toHaveBeenCalledWith(
      'instance-b',
      expect.objectContaining({ operation: 'play_card', userId: 'player-a' }),
    );
    expect(router.route).toHaveBeenCalledWith(
      'instance-b',
      expect.objectContaining({ operation: 'surrender', userId: 'player-a' }),
    );
    expect(result.emits[0].event).toBe(SERVER_MATCH_EVENTS.openCardAccepted);
  });

  it('routes reconnect and disconnect presence to the room owner', async () => {
    const route: RoomRoute = {
      roomId: 'room-remote',
      instanceId: 'instance-b',
      mode: 'ranked',
      userIds: ['player-a', 'player-b'],
    };
    coordination.userRoutes.set('player-a', route);

    await service.registerSocket('socket-a', 'player-a');
    await service.handleDisconnect('socket-a');

    expect(router.route).toHaveBeenCalledWith(
      'instance-b',
      expect.objectContaining({ operation: 'reconnect' }),
    );
    expect(router.route).toHaveBeenCalledWith(
      'instance-b',
      expect.objectContaining({ operation: 'disconnect' }),
    );
  });

  it('replays the same command acknowledgement and rejects a new fingerprint', async () => {
    const action = jest.fn().mockResolvedValue({ emits: [] });
    const first = await service.handleAcknowledgedCommand(
      'player-a',
      'command-1',
      'cancel_queue',
      { reason: 'user' },
      action,
    );
    const replay = await service.handleAcknowledgedCommand(
      'player-a',
      'command-1',
      'cancel_queue',
      { reason: 'user' },
      action,
    );
    const conflict = await service.handleAcknowledgedCommand(
      'player-a',
      'command-1',
      'cancel_queue',
      { reason: 'different' },
      action,
    );

    expect(replay.ack).toEqual(first.ack);
    expect(replay.emits).toEqual([]);
    expect(action).toHaveBeenCalledTimes(1);
    expect(conflict.ack).toEqual(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'IDEMPOTENCY_KEY_REUSED' }),
      }),
    );
  });

  it('backs Private creation and one-time join with the shared coordinator', async () => {
    const created = await service.handleCreatePrivateRoom(
      'player-a',
      'socket-a',
      { commandId: 'create-private' },
    );
    if (!('data' in created.ack)) throw new Error('Expected room code');
    const code = (created.ack.data as { code: string }).code;
    const joined = await service.handleJoinPrivateRoom('player-b', 'socket-b', {
      commandId: 'join-private',
      code,
    });
    const reused = await service.handleJoinPrivateRoom('player-c', 'socket-c', {
      commandId: 'join-private-2',
      code,
    });

    expect(
      joined.emits.filter(
        (emit) => emit.event === SERVER_MATCH_EVENTS.matchFound,
      ),
    ).toHaveLength(2);
    expect(questions.getMatchQuestionPool).toHaveBeenCalledWith(
      'cpns',
      undefined,
      ['player-a', 'player-b'],
    );
    expect(reused.ack).toEqual(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'ROOM_CODE_INVALID' }),
      }),
    );
  });
});
