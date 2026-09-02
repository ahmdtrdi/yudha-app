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
import { MatchService } from './match.service';
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
  category: ['twk', 'tiu', 'tkp'][index % 3],
  subcategory: ['pancasila_dan_ideologi', 'verbal', 'pelayanan_dan_integritas'][
    index % 3
  ],
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

describe('MatchService Energy & Economy Integration', () => {
  let service: MatchService;
  let rooms: RoomManager;
  let coordination: FakeCoordination;
  let economy: {
    reserve: jest.Mock;
    commit: jest.Mock;
    release: jest.Mock;
    releaseExpired: jest.Mock;
  };
  let matchResultService: { finalizeMatch: jest.Mock };
  let botBattle: any;

  beforeEach(() => {
    rooms = new RoomManager(new GameEngine(), new QuestionDealer());
    coordination = new FakeCoordination();
    economy = {
      reserve: jest.fn().mockResolvedValue({
        ok: true,
        data: {
          reservationId: 'res-abc',
          energyBalance: 8,
          energyCost: 2,
          unlimited: false,
        },
      }),
      commit: jest.fn().mockResolvedValue({ ok: true }),
      release: jest.fn().mockResolvedValue({ ok: true }),
      releaseExpired: jest.fn().mockResolvedValue(0),
    };
    matchResultService = {
      finalizeMatch: jest.fn().mockResolvedValue({
        progressionApplied: true,
        pvpRatingDeltaA: 15,
        pvpRatingDeltaB: -15,
        pvpRatingAfterA: 1015,
        pvpRatingAfterB: 985,
        coinsDeltaA: 10,
        coinsDeltaB: 3,
        energyDeltaA: 1,
        energyDeltaB: 1,
        energyBalanceAfterA: 9,
        energyBalanceAfterB: 9,
      }),
    };
    const profiles = {
      getProfile: jest.fn((userId: string) => Promise.resolve(profile(userId))),
      botProfile: jest.fn(() => ({
        ...profile('bot'),
        displayName: 'BOT YUDHA',
      })),
    };
    botBattle = {
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
      { getMatchQuestionPool: jest.fn().mockResolvedValue(cards) } as never,
      rooms,
      matchResultService as never,
      new MatchLogBuffer(),
      botBattle as never,
      cardTimeout as never,
      profiles as never,
      matchmaking,
      coordination as never,
      { instanceId: 'instance-a' } as never,
      { setHandler: jest.fn(), route: jest.fn() } as never,
      economy as never,
    );
  });

  it('rejects queue entry with INSUFFICIENT_ENERGY when balance is low', async () => {
    economy.reserve.mockResolvedValueOnce({
      ok: false,
      code: 'INSUFFICIENT_ENERGY',
      message: 'Energy tidak cukup.',
    });

    const result = await service.handleJoinQueue('player-poor', 'socket-poor', {
      mode: 'casual',
      commandId: 'cmd-join-1',
    });

    expect(economy.reserve).toHaveBeenCalledWith(
      'player-poor',
      'casual',
      'cmd-join-1',
      'cmd-join-1',
    );
    expect(result.emits).toEqual([
      expect.objectContaining({
        event: SERVER_MATCH_EVENTS.error,
        payload: expect.objectContaining({
          code: 'INSUFFICIENT_ENERGY',
        }),
      }),
    ]);
  });

  it('reserves energy and includes reservation details in queue_joined event', async () => {
    const result = await service.handleJoinQueue('player-a', 'socket-a', {
      mode: 'casual',
      commandId: 'cmd-join-2',
    });

    expect(economy.reserve).toHaveBeenCalledWith(
      'player-a',
      'casual',
      'cmd-join-2',
      'cmd-join-2',
    );
    expect(result.emits).toContainEqual(
      expect.objectContaining({
        event: SERVER_MATCH_EVENTS.queueJoined,
        payload: expect.objectContaining({
          energy: {
            reservationId: 'res-abc',
            energyBalance: 8,
            energyCost: 2,
            unlimited: false,
          },
        }),
      }),
    );
  });

  it('releases energy reservation on queue cancellation', async () => {
    await service.handleCancelQueue('player-a', 'socket-a');

    expect(economy.release).toHaveBeenCalledWith(
      'player-a',
      'casual',
      'cancelled',
    );
    expect(economy.release).toHaveBeenCalledWith(
      'player-a',
      'ranked',
      'cancelled',
    );
  });

  it('commits reservation on successful bot battle start', async () => {
    const result = await service.handleJoinQueue('player-bot', 'socket-bot', {
      mode: 'bot',
      commandId: 'cmd-bot-1',
    });

    expect(economy.reserve).toHaveBeenCalledWith(
      'player-bot',
      'bot',
      'cmd-bot-1',
      'cmd-bot-1',
    );
    expect(economy.commit).toHaveBeenCalledWith(
      'player-bot',
      'bot',
      'cmd-bot-1',
    );
    expect(result.emits).toContainEqual(
      expect.objectContaining({
        event: SERVER_MATCH_EVENTS.matchFound,
      }),
    );
  });

  it('releases reservation on bot battle creation failure', async () => {
    botBattle.createBotMatch.mockRejectedValueOnce(
      new Error('Engine initialization failed'),
    );

    const result = await service.handleJoinQueue('player-fail', 'socket-fail', {
      mode: 'bot',
      commandId: 'cmd-bot-fail',
    });

    expect(economy.reserve).toHaveBeenCalledWith(
      'player-fail',
      'bot',
      'cmd-bot-fail',
      'cmd-bot-fail',
    );
    expect(economy.release).toHaveBeenCalledWith(
      'player-fail',
      'bot',
      'bot_failed',
      'cmd-bot-fail',
    );
    expect(economy.commit).not.toHaveBeenCalled();
    expect(result.emits).toContainEqual(
      expect.objectContaining({
        event: SERVER_MATCH_EVENTS.error,
      }),
    );
  });

  it('reserves energy on private room creation and releases on cancel', async () => {
    const createResult = await service.handleCreatePrivateRoom(
      'player-host',
      'socket-host',
      { commandId: 'cmd-host-1' },
    );

    expect(economy.reserve).toHaveBeenCalledWith(
      'player-host',
      'private',
      'cmd-host-1',
      'cmd-host-1',
    );
    expect(createResult.ack).toEqual(
      expect.objectContaining({
        data: expect.objectContaining({
          energy: expect.objectContaining({
            reservationId: 'res-abc',
          }),
        }),
      }),
    );

    const createdData = (createResult.ack as any).data;
    await service.handleCancelPrivateRoom('player-host', 'socket-host', {
      commandId: 'cmd-cancel-1',
      code: createdData.code,
    });

    expect(economy.release).toHaveBeenCalledWith(
      'player-host',
      'private',
      'cancelled',
    );
  });

  it('releases reservations on disconnect', async () => {
    await service.registerSocket('socket-disc', 'user-disc');
    await service.handleDisconnect('socket-disc');

    expect(economy.release).toHaveBeenCalledWith(
      'user-disc',
      'casual',
      'disconnected',
    );
    expect(economy.release).toHaveBeenCalledWith(
      'user-disc',
      'ranked',
      'disconnected',
    );
    expect(economy.release).toHaveBeenCalledWith(
      'user-disc',
      'private',
      'disconnected',
    );
  });
});
