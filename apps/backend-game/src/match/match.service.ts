import { Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { SERVER_MATCH_EVENTS } from '../contracts/match.events';
import type {
  CardActionRejectedPayload,
  CancelPrivateRoomPayload,
  CreatePrivateRoomPayload,
  JoinQueuePayload,
  JoinPrivateRoomPayload,
  MatchFoundPayload,
  OpenCardPayload,
  PlayCardPayload,
  PlayCardResultPayload,
  PrivateRoomCancelledPayload,
  PrivateRoomCreatedPayload,
  PrivateRoomJoinedPayload,
  SocketCommandAck,
  SocketCommandErrorCode,
  SurrenderPayload,
} from '../contracts/match.payloads';
import type { MatchmakingMode } from '../contracts/battle-state';
import { GameCoordinationService } from '../redis/game-coordination.service';
import type {
  RedisQueueEntry,
  RoomRoute,
} from '../redis/game-coordination.types';
import { RedisService } from '../redis/redis.service';
import {
  RoomCommandRouterService,
  type RoutedRoomCommand,
} from '../redis/room-command-router.service';
import { GameEngine } from './engine/game-engine';
import type { InternalRoomState } from './engine/battle.types';
import { QuestionService } from './questions/question.service';
import type { InternalCard } from './questions/question.types';
import { MatchResultService } from './results/match-result.service';
import { RoomManager } from './rooms/room-manager';
import {
  MatchmakingService,
  type PrivateMatchmakingFailure,
} from './rooms/matchmaking.service';
import { MatchLogBuffer } from './logs/match-log-buffer';
import { BotBattleService } from './bot/bot-battle.service';
import { CardTimeoutService } from './timeout/card-timeout.service';
import {
  GamePlayerProfileService,
  type GamePlayerProfile,
} from './profiles/game-player-profile.service';

type ServerMatchEventName =
  (typeof SERVER_MATCH_EVENTS)[keyof typeof SERVER_MATCH_EVENTS];

type InternalJoinQueuePayload = Omit<JoinQueuePayload, 'commandId'> & {
  commandId?: string;
};
type InternalOpenCardPayload = Omit<OpenCardPayload, 'commandId'> & {
  commandId?: string;
};
type InternalPlayCardPayload = Omit<PlayCardPayload, 'commandId'> & {
  commandId?: string;
};
type InternalSurrenderPayload = Omit<SurrenderPayload, 'commandId'> & {
  commandId?: string;
};

export type MatchEmit = {
  socketId: string;
  event: ServerMatchEventName;
  payload: unknown;
};

export type MatchServiceResult = {
  emits: MatchEmit[];
};

type PrivateCommandData =
  | PrivateRoomCreatedPayload
  | PrivateRoomJoinedPayload
  | { code: string }
  | { accepted: true; operation: string };

export type PrivateCommandResult<
  T extends PrivateCommandData = PrivateCommandData,
> = MatchServiceResult & {
  ack: SocketCommandAck<T>;
};

type InFlightPrivateCommand = {
  fingerprint: string;
  result: Promise<PrivateCommandResult>;
};

@Injectable()
export class MatchService {
  static readonly DISCONNECT_GRACE_MS = 30_000;
  private readonly logger = new Logger(MatchService.name);
  private emitServer: ((result: MatchServiceResult) => void) | null = null;
  private readonly roundTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();
  private readonly roundBreakTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();
  private readonly disconnectTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();
  private readonly inFlightPrivateCommands = new Map<
    string,
    InFlightPrivateCommand
  >();
  private readonly queueLeaseTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();
  private readonly roomRoutes = new Map<string, RoomRoute>();
  private readonly roomRouteTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();

  constructor(
    private readonly engine: GameEngine,
    private readonly questions: QuestionService,
    private readonly rooms: RoomManager,
    private readonly matchResultService: MatchResultService,
    private readonly logBuffer: MatchLogBuffer,
    private readonly botBattleService: BotBattleService,
    private readonly cardTimeoutService: CardTimeoutService,
    private readonly profiles: GamePlayerProfileService,
    private readonly matchmaking: MatchmakingService,
    private readonly coordination: GameCoordinationService,
    private readonly redis: RedisService,
    private readonly router: RoomCommandRouterService,
  ) {
    this.router.setHandler((command) => this.handleRoutedCommand(command));
  }

  /**
   * Set by the gateway once the Server instance is available.
   * Enables async bot turns and card timeout callbacks to emit events to clients.
   */
  setEmitServer(callback: (result: MatchServiceResult) => void): void {
    this.emitServer = callback;
    this.botBattleService.setEmitCallback(callback);
    this.botBattleService.setRoundBreakCallback((room) => {
      this.handleRoundBreak(room);
    });
    this.botBattleService.setMatchFinishedCallback((room) => {
      this.clearRoundTimers(room.roomId);
      this.clearDisconnectTimersForRoom(room.roomId);
      this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
      this.scheduleRoomCleanup(room.roomId);
    });
    this.matchmaking.setExpiryCallback((reservation) => {
      if (!this.emitServer) return;
      const payload: PrivateRoomCancelledPayload = {
        code: reservation.code,
        reason: 'expired',
      };
      this.emitServer({
        emits: [
          {
            socketId: reservation.owner.socketId,
            event: SERVER_MATCH_EVENTS.privateRoomCancelled,
            payload,
          },
        ],
      });
    });
  }

  async registerSocket(
    socketId: string,
    userId: string,
  ): Promise<MatchServiceResult> {
    const result = this.rooms.registerSocket(socketId, userId);
    await this.matchmaking.rebindOwnerSocket(userId, socketId);
    if (result.type !== 'active_reconnect') {
      const route = await this.coordination.getUserRoomRoute(userId);
      if (route && route.instanceId !== this.redis.instanceId) {
        try {
          return await this.router.route<MatchServiceResult>(route.instanceId, {
            operation: 'reconnect',
            userId,
            socketId,
          });
        } catch {
          return { emits: [] };
        }
      }
      return { emits: [] };
    }
    this.clearDisconnectTimer(result.room.roomId, userId);
    return {
      emits: [
        ...this.stateEmits(result.room),
        ...this.emitPresence(result.room).emits,
      ],
    };
  }

  getUserIdForSocket(socketId: string): string | undefined {
    return this.rooms.getUserIdForSocket(socketId);
  }

  async handleDisconnect(socketId: string): Promise<MatchServiceResult> {
    const userId = this.rooms.getUserIdForSocket(socketId);
    if (userId) {
      await this.matchmaking.disconnectOwner(userId, socketId);
      this.clearQueueLease(userId);
      await this.coordination.cancelPublicQueue(userId);
    }
    const result = this.rooms.disconnectSocket(socketId);
    if (result.type === 'queued_removed') {
      return { emits: [] };
    }
    if (result.type === 'active_presence') {
      this.scheduleDisconnectForfeit(result.room, result.userId);
      return this.emitPresence(result.room);
    }
    if (userId) {
      const route = await this.coordination.getUserRoomRoute(userId);
      if (route && route.instanceId !== this.redis.instanceId) {
        try {
          return await this.router.route<MatchServiceResult>(route.instanceId, {
            operation: 'disconnect',
            userId,
            socketId,
          });
        } catch {
          return { emits: [] };
        }
      }
    }
    return { emits: [] };
  }

  async handleJoinQueue(
    userId: string,
    socketId: string,
    payload?: InternalJoinQueuePayload,
  ): Promise<MatchServiceResult> {
    const mode = payload?.mode ?? 'casual';
    if (!this.isMatchmakingMode(mode)) {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: { message: 'Mode must be ranked, casual, or bot.' },
          },
        ],
      };
    }

    if (await this.matchmaking.hasPendingPrivateRoom(userId)) {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              message:
                'Batalkan ruang Private sebelum memulai matchmaking lain.',
            },
          },
        ],
      };
    }

    let profile: GamePlayerProfile;
    try {
      profile = await this.profiles.getProfile(userId);
    } catch (error) {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              message:
                error instanceof Error
                  ? error.message
                  : 'Game profile is unavailable.',
            },
          },
        ],
      };
    }

    // Bot mode: skip queue, create match instantly
    if (mode === 'bot') {
      return this.handleBotMode(profile, socketId);
    }

    const matchmakingStartedAt = Date.now();
    const queueResult = await this.coordination.joinPublicQueue(
      profile,
      socketId,
      mode,
    );
    this.logger.log(
      `Redis matchmaking result=${queueResult.type} target=${profile.target} mode=${mode} latencyMs=${Date.now() - matchmakingStartedAt}.`,
    );

    if (queueResult.type === 'unavailable') {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              code: 'QUEUE_UNAVAILABLE',
              message: 'Matchmaking sedang tidak tersedia. Coba lagi.',
              details: { recoverable: true },
            },
          },
        ],
      };
    }

    if (queueResult.type === 'conflict') {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: { message: 'You are already in an active match.' },
          },
        ],
      };
    }

    if (queueResult.type === 'queued') {
      this.scheduleQueueLease(queueResult.entry);
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.queueJoined,
            payload: {
              position: queueResult.position,
              queueDepth: queueResult.depth,
              mode,
              target: profile.target,
            },
          },
        ],
      };
    }

    this.clearQueueLease(queueResult.opponent.userId);
    this.clearQueueLease(userId);
    let cards: InternalCard[];
    try {
      cards = await this.questions.getMatchQuestionPool(profile.target);
    } catch (error) {
      await this.coordination.restorePublicPair([
        queueResult.opponent,
        queueResult.entry,
      ]);
      this.scheduleQueueLease(queueResult.entry);
      this.logger.error(
        `Failed to prepare matched question pool: ${error instanceof Error ? error.message : String(error)}`,
      );
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              code: 'QUEUE_UNAVAILABLE',
              message: 'Pertandingan belum dapat dimulai. Coba lagi.',
              details: { recoverable: true },
            },
          },
        ],
      };
    }

    const playerA = queueResult.opponent;
    const playerB = queueResult.entry;
    let room: InternalRoomState;
    try {
      room = this.rooms.createPublicRoom(playerA, playerB, mode, cards);
    } catch (error) {
      await this.coordination.restorePublicPair([playerA, playerB]);
      this.scheduleQueueLease(playerB);
      this.logger.error(
        `Failed to create matched room: ${error instanceof Error ? error.message : String(error)}`,
      );
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              code: 'QUEUE_UNAVAILABLE',
              message: 'Pertandingan belum dapat dimulai. Coba lagi.',
              details: { recoverable: true },
            },
          },
        ],
      };
    }
    const route: RoomRoute = {
      roomId: room.roomId,
      instanceId: this.redis.instanceId,
      mode,
      userIds: [playerA.userId, playerB.userId],
    };
    if (!(await this.coordination.registerRoom(route))) {
      this.rooms.destroyRoom(room.roomId);
      await this.coordination.restorePublicPair([playerA, playerB]);
      this.scheduleQueueLease(playerB);
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              code: 'QUEUE_UNAVAILABLE',
              message: 'Pertandingan belum dapat dimulai. Coba lagi.',
              details: { recoverable: true },
            },
          },
        ],
      };
    }
    this.roomRoutes.set(room.roomId, route);
    this.scheduleRoomRouteRefresh(route);

    const emits: MatchEmit[] = [
      {
        socketId,
        event: SERVER_MATCH_EVENTS.queueJoined,
        payload: {
          position: 0,
          queueDepth: 0,
          mode,
          target: profile.target,
        },
      },
    ];

    const matchFoundA: MatchFoundPayload = {
      roomId: room.roomId,
      opponentUserId: playerB.userId,
      opponentDisplayName: playerB.displayName,
      opponentLoadout: playerB.loadout,
      role: 'playerA',
      mode: room.mode,
      target: room.target,
    };
    const matchFoundB: MatchFoundPayload = {
      roomId: room.roomId,
      opponentUserId: playerA.userId,
      opponentDisplayName: playerA.displayName,
      opponentLoadout: playerA.loadout,
      role: 'playerB',
      mode: room.mode,
      target: room.target,
    };

    emits.push(
      {
        socketId: playerA.socketId,
        event: SERVER_MATCH_EVENTS.matchFound,
        payload: matchFoundA,
      },
      {
        socketId: playerB.socketId,
        event: SERVER_MATCH_EVENTS.matchFound,
        payload: matchFoundB,
      },
      ...this.stateEmits(room),
    );
    this.scheduleRoundTimeout(room);

    return { emits };
  }

  async handleCreatePrivateRoom(
    userId: string,
    socketId: string,
    payload?: CreatePrivateRoomPayload,
  ): Promise<PrivateCommandResult> {
    return this.executePrivateCommand(
      userId,
      payload?.commandId,
      'create_private_room',
      'create_private_room',
      async (requestId) => {
        const profile = await this.loadPrivateProfile(userId, requestId);
        if (!profile.ok) return profile.result;

        const created = await this.matchmaking.createPrivateRoom(
          profile.profile,
          socketId,
        );
        if (!created.ok) {
          return this.privateMatchmakingFailure(created.reason, requestId);
        }

        const data: PrivateRoomCreatedPayload = {
          code: created.reservation.code,
          target: created.reservation.target,
          expiresAt: created.reservation.expiresAt.toISOString(),
        };
        return {
          ack: { data, requestId },
          emits: [
            {
              socketId,
              event: SERVER_MATCH_EVENTS.privateRoomCreated,
              payload: data,
            },
          ],
        };
      },
    );
  }

  async handleJoinPrivateRoom(
    userId: string,
    socketId: string,
    payload?: JoinPrivateRoomPayload,
    routed = false,
  ): Promise<PrivateCommandResult> {
    const code = payload?.code;
    if (!routed && this.isPrivateRoomCode(code)) {
      const reservation = await this.coordination.getPrivateReservation(code);
      if (
        reservation &&
        reservation.owner.instanceId !== this.redis.instanceId
      ) {
        try {
          return await this.router.route<PrivateCommandResult>(
            reservation.owner.instanceId,
            {
              operation: 'join_private_room',
              userId,
              socketId,
              payload,
            },
          );
        } catch {
          return this.privateError(
            randomUUID(),
            'QUEUE_UNAVAILABLE',
            'Ruang Private sedang tidak tersedia. Coba lagi.',
            true,
          );
        }
      }
    }
    const fingerprint = `join_private_room:${typeof code === 'string' ? code : ''}`;
    return this.executePrivateCommand(
      userId,
      payload?.commandId,
      fingerprint,
      'join_private_room',
      async (requestId) => {
        if (!this.isPrivateRoomCode(code)) {
          return this.privateError(
            requestId,
            'VALIDATION_FAILED',
            'Kode ruang harus terdiri dari enam karakter yang valid.',
            false,
          );
        }

        const profile = await this.loadPrivateProfile(userId, requestId);
        if (!profile.ok) return profile.result;

        const validation = await this.matchmaking.validateJoin(
          profile.profile,
          code,
        );
        if (!validation.ok) {
          return this.privateMatchmakingFailure(validation.reason, requestId);
        }

        let cards: InternalCard[];
        try {
          cards = await this.questions.getMatchQuestionPool(
            profile.profile.target,
          );
        } catch {
          return this.privateError(
            requestId,
            'QUEUE_UNAVAILABLE',
            'Pertandingan Private belum dapat dimulai. Coba lagi.',
            true,
          );
        }

        let joined: Awaited<ReturnType<MatchmakingService['joinPrivateRoom']>>;
        try {
          joined = await this.matchmaking.joinPrivateRoom(
            profile.profile,
            socketId,
            code,
            cards,
          );
        } catch (error) {
          this.logger.error(
            `Failed to create private room: ${error instanceof Error ? error.message : String(error)}`,
          );
          return this.privateError(
            requestId,
            'QUEUE_UNAVAILABLE',
            'Pertandingan Private belum dapat dimulai. Coba lagi.',
            true,
          );
        }
        if (!joined.ok) {
          return this.privateMatchmakingFailure(joined.reason, requestId);
        }

        const { room, playerA, playerB } = joined.match;
        const route: RoomRoute = {
          roomId: room.roomId,
          instanceId: this.redis.instanceId,
          mode: 'private',
          userIds: [playerA.userId, playerB.userId],
        };
        if (!(await this.coordination.registerRoom(route))) {
          this.rooms.destroyRoom(room.roomId);
          return this.privateError(
            requestId,
            'QUEUE_UNAVAILABLE',
            'Pertandingan Private belum dapat dimulai. Coba lagi.',
            true,
          );
        }
        this.roomRoutes.set(room.roomId, route);
        this.scheduleRoomRouteRefresh(route);
        const data: PrivateRoomJoinedPayload = { code, roomId: room.roomId };
        const matchFoundA: MatchFoundPayload = {
          roomId: room.roomId,
          opponentUserId: playerB.userId,
          opponentDisplayName: playerB.displayName,
          opponentLoadout: playerB.loadout,
          role: 'playerA',
          mode: 'private',
          target: room.target,
        };
        const matchFoundB: MatchFoundPayload = {
          roomId: room.roomId,
          opponentUserId: playerA.userId,
          opponentDisplayName: playerA.displayName,
          opponentLoadout: playerA.loadout,
          role: 'playerB',
          mode: 'private',
          target: room.target,
        };
        const emits: MatchEmit[] = [
          {
            socketId: playerA.socketId,
            event: SERVER_MATCH_EVENTS.privateRoomJoined,
            payload: data,
          },
          {
            socketId: playerB.socketId,
            event: SERVER_MATCH_EVENTS.privateRoomJoined,
            payload: data,
          },
          {
            socketId: playerA.socketId,
            event: SERVER_MATCH_EVENTS.matchFound,
            payload: matchFoundA,
          },
          {
            socketId: playerB.socketId,
            event: SERVER_MATCH_EVENTS.matchFound,
            payload: matchFoundB,
          },
          ...this.stateEmits(room),
        ];
        this.scheduleRoundTimeout(room);
        return { ack: { data, requestId }, emits };
      },
    );
  }

  async handleCancelPrivateRoom(
    userId: string,
    socketId: string,
    payload?: CancelPrivateRoomPayload,
  ): Promise<PrivateCommandResult> {
    const code = payload?.code;
    const fingerprint = `cancel_private_room:${typeof code === 'string' ? code : ''}`;
    return this.executePrivateCommand(
      userId,
      payload?.commandId,
      fingerprint,
      'cancel_private_room',
      async (requestId) => {
        if (!this.isPrivateRoomCode(code)) {
          return this.privateError(
            requestId,
            'VALIDATION_FAILED',
            'Kode ruang harus terdiri dari enam karakter yang valid.',
            false,
          );
        }
        const cancelled = await this.matchmaking.cancelPrivateRoom(
          userId,
          code,
        );
        if (!cancelled.ok) {
          return this.privateMatchmakingFailure(cancelled.reason, requestId);
        }
        const data = { code };
        const eventPayload: PrivateRoomCancelledPayload = {
          code,
          reason: 'cancelled',
        };
        return {
          ack: { data, requestId },
          emits: [
            {
              socketId,
              event: SERVER_MATCH_EVENTS.privateRoomCancelled,
              payload: eventPayload,
            },
          ],
        };
      },
    );
  }

  private async handleBotMode(
    profile: GamePlayerProfile,
    socketId: string,
  ): Promise<MatchServiceResult> {
    const { userId } = profile;
    // Check if user is already in an active match
    const existingRoom = this.rooms.getRoomForUser(userId);
    if (existingRoom && existingRoom.status === 'active') {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: { message: 'You are already in an active match.' },
          },
        ],
      };
    }

    let room: InternalRoomState;
    try {
      room = await this.botBattleService.createBotMatch(profile, socketId);
    } catch (error) {
      this.logger.error(
        `Failed to create bot room: ${error instanceof Error ? error.message : String(error)}`,
      );
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              code: 'QUEUE_UNAVAILABLE',
              message: 'Pertandingan Bot belum dapat dimulai. Coba lagi.',
              details: { recoverable: true },
            },
          },
        ],
      };
    }
    const bot = room.players.playerB;
    if (this.coordination.available) {
      const route: RoomRoute = {
        roomId: room.roomId,
        instanceId: this.redis.instanceId,
        mode: 'bot',
        userIds: [userId],
      };
      if (await this.coordination.registerRoom(route)) {
        this.roomRoutes.set(room.roomId, route);
        this.scheduleRoomRouteRefresh(route);
      }
    }
    this.scheduleRoundTimeout(room);

    const matchFound: MatchFoundPayload = {
      roomId: room.roomId,
      opponentUserId: 'bot',
      opponentDisplayName: bot.displayName,
      opponentLoadout: bot.loadout,
      role: 'playerA',
      mode: room.mode,
      target: room.target,
    };

    return {
      emits: [
        {
          socketId,
          event: SERVER_MATCH_EVENTS.matchFound,
          payload: matchFound,
        },
        ...this.stateEmits(room),
      ],
    };
  }

  async handleCancelQueue(
    userId: string,
    socketId: string,
  ): Promise<MatchServiceResult> {
    this.clearQueueLease(userId);
    const removed = await this.coordination.cancelPublicQueue(userId);
    return {
      emits: removed
        ? [
            {
              socketId,
              event: SERVER_MATCH_EVENTS.queueCancelled,
              payload: { reason: 'cancelled' },
            },
          ]
        : [],
    };
  }

  async handleOpenCard(
    userId: string,
    socketId: string,
    payload?: InternalOpenCardPayload,
    routed = false,
  ): Promise<MatchServiceResult> {
    if (
      !payload ||
      typeof payload.roomId !== 'string' ||
      typeof payload.cardId !== 'string'
    ) {
      return this.reject(
        socketId,
        'open_card',
        undefined,
        'invalid_payload',
        'roomId and cardId are required.',
        false,
      );
    }
    if (!routed) {
      const remote = await this.routeRoomCommand(
        payload.roomId,
        'open_card',
        userId,
        socketId,
        payload,
      );
      if (remote) return remote;
    }
    const room = this.rooms.getRoom(payload.roomId);
    if (!room)
      return this.reject(
        socketId,
        'open_card',
        payload.roomId,
        'room_not_found',
        'Room not found.',
      );

    const result = this.engine.openCard(room, userId, payload.cardId);
    if (!result.ok) {
      return this.reject(
        socketId,
        'open_card',
        payload.roomId,
        result.reason,
        result.message,
        result.recoverable,
      );
    }

    // Log the open_card action
    this.logBuffer.record(payload.roomId, userId, 'open_card', {
      cardId: payload.cardId,
      questionId: this.engine
        .getPlayer(room, userId)
        ?.hand.find((card) => card.id === payload.cardId)?.sourceQuestionId,
    });

    // Schedule per-card turn timeout if this is a human player
    if (userId !== 'bot') {
      const player = this.engine.getPlayer(room, userId);
      const card = player?.hand.find((c) => c.id === payload.cardId);
      this.cardTimeoutService.scheduleTimeout(
        payload.roomId,
        userId,
        payload.cardId,
        card?.timeLimitSeconds,
        (rId, uId, cId) => {
          void this.handleCardTimeout(rId, uId, cId);
        },
      );
    }

    return {
      emits: [
        {
          socketId,
          event: SERVER_MATCH_EVENTS.openCardAccepted,
          payload: { roomId: payload.roomId, cardId: payload.cardId },
        },
        ...this.stateEmits(room),
      ],
    };
  }

  async handlePlayCard(
    userId: string,
    socketId: string,
    payload?: InternalPlayCardPayload,
    routed = false,
  ): Promise<MatchServiceResult> {
    if (
      !payload ||
      typeof payload.roomId !== 'string' ||
      typeof payload.cardId !== 'string' ||
      !Number.isInteger(payload.selectedOptionIndex)
    ) {
      return this.reject(
        socketId,
        'play_card',
        undefined,
        'invalid_payload',
        'roomId, cardId, and an integer selectedOptionIndex are required.',
        false,
      );
    }
    if (!routed) {
      const remote = await this.routeRoomCommand(
        payload.roomId,
        'play_card',
        userId,
        socketId,
        payload,
      );
      if (remote) return remote;
    }
    const room = this.rooms.getRoom(payload.roomId);
    if (!room)
      return this.reject(
        socketId,
        'play_card',
        payload.roomId,
        'room_not_found',
        'Room not found.',
      );

    // Clear card timeout timer before executing answer
    this.cardTimeoutService.clearTimeout(payload.roomId, userId);

    const playerBefore = this.engine.getPlayer(room, userId);
    const opponentBefore = this.engine.getOpponent(room, userId);
    const cardBefore = playerBefore?.hand.find(
      (card) => card.id === payload.cardId,
    );
    const snapshotBefore = {
      hp: playerBefore?.hp,
      opponentHp: opponentBefore?.hp,
      points: playerBefore?.points,
      responseTimeMs: playerBefore?.openedCardAt
        ? Math.max(0, Date.now() - playerBefore.openedCardAt.getTime())
        : undefined,
    };

    const result = this.engine.playCard(
      room,
      userId,
      payload.cardId,
      payload.selectedOptionIndex,
    );
    if (!result.ok) {
      return this.reject(
        socketId,
        'play_card',
        payload.roomId,
        result.reason,
        result.message,
        result.recoverable,
      );
    }

    // Log the play_card action
    this.logBuffer.record(payload.roomId, userId, 'play_card', {
      cardId: payload.cardId,
      questionId: cardBefore?.sourceQuestionId,
      selectedOptionIndex: payload.selectedOptionIndex,
      playerAnswer: cardBefore?.options[payload.selectedOptionIndex],
      correct: result.playResult.correct,
      effect: result.playResult.effect,
      effectValue: result.playResult.effectValue,
      hpBefore: snapshotBefore.hp,
      hpAfter: playerBefore?.hp,
      opponentHpBefore: snapshotBefore.opponentHp,
      opponentHpAfter: opponentBefore?.hp,
      pointsBefore: snapshotBefore.points,
      pointsAfter: playerBefore?.points,
      responseTimeMs: snapshotBefore.responseTimeMs,
    });

    const emits: MatchEmit[] = [
      ...this.playResultEmits(room, result.playResult),
      ...this.stateEmits(room),
    ];

    if (result.matchResult) {
      this.clearRoundTimers(room.roomId);
      this.botBattleService.cancelBotSchedule(room.roomId);
      this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
      await this.persistAndEnrich(room);
      this.clearDisconnectTimersForRoom(room.roomId);
      emits.push(...this.matchResultEmits(room));
      this.scheduleRoomCleanup(room.roomId);
    } else if (room.roundStatus === 'break') {
      this.botBattleService.cancelBotSchedule(room.roomId);
      this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
      this.scheduleRoundTransition(room);
    }

    return { emits };
  }

  async handleCardTimeout(
    roomId: string,
    userId: string,
    cardId: string,
  ): Promise<void> {
    const room = this.rooms.getRoom(roomId);
    if (!room || room.status !== 'active') return;

    const playerBefore = this.engine.getPlayer(room, userId);
    const opponentBefore = this.engine.getOpponent(room, userId);
    const cardBefore = playerBefore?.hand.find((card) => card.id === cardId);
    const snapshotBefore = {
      hp: playerBefore?.hp,
      opponentHp: opponentBefore?.hp,
      points: playerBefore?.points,
      responseTimeMs: playerBefore?.openedCardAt
        ? Math.max(0, Date.now() - playerBefore.openedCardAt.getTime())
        : undefined,
    };
    const result = this.engine.timeoutCard(room, userId, cardId);
    if (!result.ok) return;

    // Log the timeout action
    this.logBuffer.record(roomId, userId, 'timeout', {
      cardId,
      questionId: cardBefore?.sourceQuestionId,
      hpBefore: snapshotBefore.hp,
      hpAfter: playerBefore?.hp,
      opponentHpBefore: snapshotBefore.opponentHp,
      opponentHpAfter: opponentBefore?.hp,
      pointsBefore: snapshotBefore.points,
      pointsAfter: playerBefore?.points,
      responseTimeMs: snapshotBefore.responseTimeMs,
    });

    const emits: MatchEmit[] = [
      ...this.playResultEmits(room, result.playResult),
      ...this.stateEmits(room),
    ];

    if (result.matchResult) {
      this.clearRoundTimers(room.roomId);
      this.botBattleService.cancelBotSchedule(room.roomId);
      this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
      await this.persistAndEnrich(room);
      this.clearDisconnectTimersForRoom(room.roomId);
      emits.push(...this.matchResultEmits(room));
      this.scheduleRoomCleanup(room.roomId);
    } else if (room.roundStatus === 'break') {
      this.botBattleService.cancelBotSchedule(room.roomId);
      this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
      this.scheduleRoundTransition(room);
    }

    if (this.emitServer && emits.length > 0) {
      this.emitServer({ emits });
    }
  }

  async handleSurrender(
    userId: string,
    socketId: string,
    payload?: InternalSurrenderPayload,
    routed = false,
  ): Promise<MatchServiceResult> {
    if (!payload || typeof payload.roomId !== 'string') {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: { message: 'roomId is required.' },
          },
        ],
      };
    }
    if (!routed) {
      const remote = await this.routeRoomCommand(
        payload.roomId,
        'surrender',
        userId,
        socketId,
        payload,
      );
      if (remote) return remote;
    }
    const room = this.rooms.getRoom(payload.roomId);
    if (!room) {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: { message: 'Room not found.' },
          },
        ],
      };
    }

    const player = this.engine.getPlayer(room, userId);
    const opponent = this.engine.getOpponent(room, userId);

    const result = this.engine.surrender(room, userId);
    if (!result.ok) {
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: { message: result.message },
          },
        ],
      };
    }

    // Log the surrender action
    this.logBuffer.record(payload.roomId, userId, 'surrender', {
      atHpSelf: player?.hp ?? 0,
      atHpOpponent: opponent?.hp ?? 0,
    });

    this.botBattleService.cancelBotSchedule(room.roomId);
    this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
    this.clearRoundTimers(room.roomId);
    await this.persistAndEnrich(room);
    this.clearDisconnectTimersForRoom(room.roomId);
    this.scheduleRoomCleanup(room.roomId);
    return {
      emits: [...this.stateEmits(room), ...this.matchResultEmits(room)],
    };
  }

  private scheduleRoundTimeout(room: InternalRoomState): void {
    const existing = this.roundTimers.get(room.roomId);
    if (existing) clearTimeout(existing);
    if (
      room.status !== 'active' ||
      room.roundStatus !== 'active' ||
      !room.roundEndsAt
    ) {
      this.roundTimers.delete(room.roomId);
      return;
    }
    const delay = Math.max(0, room.roundEndsAt.getTime() - Date.now());
    const timer = setTimeout(() => {
      this.roundTimers.delete(room.roomId);
      void this.handleRoundTimeout(room.roomId);
    }, delay);
    timer.unref?.();
    this.roundTimers.set(room.roomId, timer);
  }

  private scheduleRoundTransition(room: InternalRoomState): void {
    const roundTimer = this.roundTimers.get(room.roomId);
    if (roundTimer) clearTimeout(roundTimer);
    this.roundTimers.delete(room.roomId);
    const existing = this.roundBreakTimers.get(room.roomId);
    if (existing) clearTimeout(existing);
    if (
      room.status !== 'active' ||
      room.roundStatus !== 'break' ||
      !room.nextRoundAt
    ) {
      this.roundBreakTimers.delete(room.roomId);
      return;
    }
    const delay = Math.max(0, room.nextRoundAt.getTime() - Date.now());
    const timer = setTimeout(() => {
      this.roundBreakTimers.delete(room.roomId);
      this.startNextRound(room.roomId);
    }, delay);
    timer.unref?.();
    this.roundBreakTimers.set(room.roomId, timer);
  }

  private async handleRoundTimeout(roomId: string): Promise<void> {
    const room = this.rooms.getRoom(roomId);
    if (!room || room.status !== 'active' || room.roundStatus !== 'active') {
      return;
    }

    this.botBattleService.cancelBotSchedule(roomId);
    this.cardTimeoutService.cancelAllTimersForRoom(roomId);
    const matchResult = this.engine.finishRoundOnTimeout(room);
    const emits = [...this.stateEmits(room)];
    if (matchResult) {
      this.clearRoundTimers(roomId);
      this.clearDisconnectTimersForRoom(roomId);
      await this.persistAndEnrich(room);
      emits.push(...this.matchResultEmits(room));
      this.scheduleRoomCleanup(roomId);
    } else {
      this.scheduleRoundTransition(room);
    }
    if (this.emitServer && emits.length > 0) {
      this.emitServer({ emits });
    }
  }

  private startNextRound(roomId: string): void {
    const room = this.rooms.getRoom(roomId);
    if (!room || !this.engine.startNextRound(room)) {
      return;
    }
    this.scheduleRoundTimeout(room);
    if (this.botBattleService.isBotMatch(room)) {
      this.botBattleService.resumeBotSchedule(roomId);
    }
    if (this.emitServer) {
      this.emitServer({ emits: this.stateEmits(room) });
    }
  }

  private handleRoundBreak(room: InternalRoomState): void {
    this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
    const emits = this.stateEmits(room);
    this.scheduleRoundTransition(room);
    if (this.emitServer && emits.length > 0) {
      this.emitServer({ emits });
    }
  }

  private clearRoundTimers(roomId: string): void {
    const roundTimer = this.roundTimers.get(roomId);
    if (roundTimer) clearTimeout(roundTimer);
    this.roundTimers.delete(roomId);
    const breakTimer = this.roundBreakTimers.get(roomId);
    if (breakTimer) clearTimeout(breakTimer);
    this.roundBreakTimers.delete(roomId);
  }

  private stateEmits(room: InternalRoomState): MatchEmit[] {
    return this.rooms
      .listRoomUsers(room)
      .map((userId): MatchEmit | undefined => {
        const socketId = this.rooms.getSocketIdForUser(userId, room);
        if (!socketId) return undefined;
        return {
          socketId,
          event: SERVER_MATCH_EVENTS.gameStateUpdate,
          payload: this.engine.buildPublicState(room, userId),
        };
      })
      .filter((emit): emit is MatchEmit => Boolean(emit));
  }

  private playResultEmits(
    room: InternalRoomState,
    payload: PlayCardResultPayload,
  ): MatchEmit[] {
    return this.rooms
      .listRoomUsers(room)
      .map((userId): MatchEmit | undefined => {
        const socketId = this.rooms.getSocketIdForUser(userId, room);
        if (!socketId) return undefined;
        return {
          socketId,
          event: SERVER_MATCH_EVENTS.playCardResult,
          payload,
        };
      })
      .filter((emit): emit is MatchEmit => Boolean(emit));
  }

  private matchResultEmits(room: InternalRoomState): MatchEmit[] {
    if (!room.result) return [];
    return this.rooms
      .listRoomUsers(room)
      .map((userId) => this.rooms.getSocketIdForUser(userId, room))
      .filter((socketId): socketId is string => Boolean(socketId))
      .map((socketId) => ({
        socketId,
        event: SERVER_MATCH_EVENTS.matchResult,
        payload: room.result,
      }));
  }

  private emitPresence(room: InternalRoomState): MatchServiceResult {
    const payload = {
      roomId: room.roomId,
      players: Object.fromEntries(
        this.rooms.listRoomUsers(room).map((userId) => {
          const player = this.engine.getPlayer(room, userId)!;
          return [
            userId,
            {
              connected: player.connected,
              ...(player.reconnectDeadline
                ? { reconnectDeadline: player.reconnectDeadline.toISOString() }
                : {}),
            },
          ];
        }),
      ),
    };
    return {
      emits: this.rooms
        .listRoomUsers(room)
        .map((userId) => this.rooms.getSocketIdForUser(userId, room))
        .filter((socketId): socketId is string => Boolean(socketId))
        .map((socketId) => ({
          socketId,
          event: SERVER_MATCH_EVENTS.presenceUpdate,
          payload,
        })),
    };
  }

  /**
   * Persist match result to Supabase and enrich room.result with rating/coin deltas.
   * Also flushes the match log buffer into Supabase alongside the result.
   * Non-blocking: logs errors but never throws.
   */
  private async persistAndEnrich(room: InternalRoomState): Promise<void> {
    // Drain log buffer before persistence
    const logEntries = this.logBuffer.drain(room.roomId);
    const rpcLogs = this.logBuffer.toRpcEntries(logEntries);

    try {
      const deltas = await this.matchResultService.finalizeMatch(room, rpcLogs);
      if (deltas && room.result) {
        room.result.progressionPersisted = deltas.progressionApplied;
        room.result.finalState.playerA.ratingDelta = deltas.ratingDeltaA;
        room.result.finalState.playerA.coinsDelta = deltas.coinsDeltaA;
        room.result.finalState.playerB.ratingDelta = deltas.ratingDeltaB;
        room.result.finalState.playerB.coinsDelta = deltas.coinsDeltaB;
      } else if (room.result) {
        room.result.progressionPersisted = false;
      }
    } catch (error) {
      if (room.result) {
        room.result.progressionPersisted = false;
      }
      this.logger.error(
        `Failed to persist match ${room.roomId}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private scheduleDisconnectForfeit(
    room: InternalRoomState,
    userId: string,
  ): void {
    this.clearDisconnectTimer(room.roomId, userId);
    const player = this.engine.getPlayer(room, userId);
    if (!player || room.status !== 'active') return;

    player.reconnectDeadline = new Date(
      Date.now() + MatchService.DISCONNECT_GRACE_MS,
    );
    const key = this.disconnectTimerKey(room.roomId, userId);
    const timer = setTimeout(() => {
      this.disconnectTimers.delete(key);
      void this.handleDisconnectGraceExpired(room.roomId, userId);
    }, MatchService.DISCONNECT_GRACE_MS);
    timer.unref?.();
    this.disconnectTimers.set(key, timer);
  }

  private async handleDisconnectGraceExpired(
    roomId: string,
    userId: string,
  ): Promise<void> {
    const room = this.rooms.getRoom(roomId);
    const player = room ? this.engine.getPlayer(room, userId) : undefined;
    if (!room || room.status !== 'active' || !player || player.connected) {
      return;
    }

    this.engine.finishDisconnected(room, userId);
    this.botBattleService.cancelBotSchedule(room.roomId);
    this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
    this.clearRoundTimers(room.roomId);
    this.clearDisconnectTimersForRoom(room.roomId);
    await this.persistAndEnrich(room);

    const emits = [
      ...this.stateEmits(room),
      ...this.matchResultEmits(room),
      ...this.emitPresence(room).emits,
    ];
    if (this.emitServer && emits.length > 0) {
      this.emitServer({ emits });
    }
    this.scheduleRoomCleanup(room.roomId);
  }

  private clearDisconnectTimer(roomId: string, userId: string): void {
    const key = this.disconnectTimerKey(roomId, userId);
    const timer = this.disconnectTimers.get(key);
    if (timer) clearTimeout(timer);
    this.disconnectTimers.delete(key);
  }

  private clearDisconnectTimersForRoom(roomId: string): void {
    const prefix = `${roomId}:`;
    for (const [key, timer] of this.disconnectTimers) {
      if (!key.startsWith(prefix)) continue;
      clearTimeout(timer);
      this.disconnectTimers.delete(key);
    }
  }

  private disconnectTimerKey(roomId: string, userId: string): string {
    return `${roomId}:${userId}`;
  }

  private async executePrivateCommand(
    userId: string,
    commandId: unknown,
    fingerprint: string,
    operation: string,
    execute: (
      requestId: string,
    ) => PrivateCommandResult | Promise<PrivateCommandResult>,
  ): Promise<PrivateCommandResult> {
    if (
      typeof commandId !== 'string' ||
      commandId.length < 1 ||
      commandId.length > 160
    ) {
      return this.privateError(
        randomUUID(),
        'VALIDATION_FAILED',
        'commandId wajib diisi dengan panjang 1 sampai 160 karakter.',
        false,
      );
    }

    const cacheKey = `${userId}:${commandId}`;
    const fullFingerprint = `${operation}:${fingerprint}`;
    const inFlight = this.inFlightPrivateCommands.get(cacheKey);
    if (inFlight) {
      if (inFlight.fingerprint !== fullFingerprint) {
        return this.privateError(
          randomUUID(),
          'IDEMPOTENCY_KEY_REUSED',
          'Command ID sudah digunakan untuk permintaan yang berbeda.',
          false,
        );
      }
      const replay = await inFlight.result;
      return { ack: replay.ack, emits: [] };
    }

    const claim = await this.coordination.claimCommand(
      userId,
      commandId,
      fullFingerprint,
    );
    if (claim.type === 'unavailable') {
      return this.privateError(
        claim.requestId,
        'QUEUE_UNAVAILABLE',
        'Koordinasi command sedang tidak tersedia. Coba lagi.',
        true,
      );
    }
    if (claim.type === 'conflict') {
      return this.privateError(
        claim.requestId,
        'IDEMPOTENCY_KEY_REUSED',
        'Command ID sudah digunakan untuk permintaan yang berbeda.',
        false,
      );
    }
    if (claim.type === 'replay') {
      return {
        ack: claim.acknowledgement as SocketCommandAck<PrivateCommandData>,
        emits: [],
      };
    }
    if (claim.type === 'pending') {
      for (let attempt = 0; attempt < 20; attempt += 1) {
        await new Promise<void>((resolve) => setTimeout(resolve, 50));
        const replay = await this.coordination.claimCommand(
          userId,
          commandId,
          fullFingerprint,
        );
        if (replay.type === 'replay') {
          return {
            ack: replay.acknowledgement as SocketCommandAck<PrivateCommandData>,
            emits: [],
          };
        }
        if (replay.type === 'conflict') {
          return this.privateError(
            replay.requestId,
            'IDEMPOTENCY_KEY_REUSED',
            'Command ID sudah digunakan untuk permintaan yang berbeda.',
            false,
          );
        }
        if (replay.type === 'unavailable') break;
      }
      return this.privateError(
        claim.requestId,
        'CONFLICT',
        'Command yang sama masih diproses.',
        true,
      );
    }

    const resultPromise = Promise.resolve(execute(claim.requestId));
    this.inFlightPrivateCommands.set(cacheKey, {
      fingerprint: fullFingerprint,
      result: resultPromise,
    });
    try {
      const result = await resultPromise;
      await this.coordination.completeCommand(
        userId,
        commandId,
        fullFingerprint,
        claim.requestId,
        result.ack,
      );
      return result;
    } finally {
      this.inFlightPrivateCommands.delete(cacheKey);
    }
  }

  private async loadPrivateProfile(
    userId: string,
    requestId: string,
  ): Promise<
    | { ok: true; profile: GamePlayerProfile }
    | { ok: false; result: PrivateCommandResult }
  > {
    try {
      return { ok: true, profile: await this.profiles.getProfile(userId) };
    } catch {
      return {
        ok: false,
        result: this.privateError(
          requestId,
          'QUEUE_UNAVAILABLE',
          'Profil permainan belum tersedia. Coba lagi.',
          true,
        ),
      };
    }
  }

  private privateMatchmakingFailure(
    reason: PrivateMatchmakingFailure,
    requestId: string,
  ): PrivateCommandResult {
    if (reason === 'matchmaking_conflict') {
      return this.privateError(
        requestId,
        'CONFLICT',
        'Selesaikan atau batalkan matchmaking yang sedang aktif terlebih dahulu.',
        true,
      );
    }
    if (reason === 'code_generation_failed' || reason === 'queue_unavailable') {
      return this.privateError(
        requestId,
        'QUEUE_UNAVAILABLE',
        'Kode ruang belum dapat dibuat. Coba lagi.',
        true,
      );
    }
    return this.privateError(
      requestId,
      'ROOM_CODE_INVALID',
      'Kode ruang tidak valid atau sudah tidak tersedia.',
      true,
    );
  }

  private privateError(
    requestId: string,
    code: SocketCommandErrorCode,
    message: string,
    recoverable: boolean,
  ): PrivateCommandResult {
    return {
      ack: {
        error: {
          code,
          message,
          details: { recoverable },
          requestId,
        },
      },
      emits: [],
    };
  }

  private isPrivateRoomCode(value: unknown): value is string {
    return (
      typeof value === 'string' &&
      /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/.test(value)
    );
  }

  private isMatchmakingMode(
    value: unknown,
  ): value is Exclude<MatchmakingMode, 'private'> {
    return value === 'ranked' || value === 'casual' || value === 'bot';
  }

  async handleAcknowledgedCommand(
    userId: string,
    commandId: unknown,
    operation: string,
    payload: unknown,
    action: () => MatchServiceResult | Promise<MatchServiceResult>,
  ): Promise<PrivateCommandResult> {
    const fingerprint = JSON.stringify(payload ?? null);
    return this.executePrivateCommand(
      userId,
      commandId,
      fingerprint,
      operation,
      async (requestId) => {
        const result = await action();
        const failure = result.emits.find(
          (emit) =>
            emit.event === SERVER_MATCH_EVENTS.error ||
            emit.event === SERVER_MATCH_EVENTS.cardActionRejected,
        );
        if (failure) {
          const errorPayload = failure.payload as {
            code?: SocketCommandErrorCode;
            message?: string;
            recoverable?: boolean;
            details?: { recoverable?: boolean };
          };
          return {
            ack: {
              error: {
                code: errorPayload.code ?? 'CONFLICT',
                message: errorPayload.message ?? 'Command ditolak oleh server.',
                details: {
                  recoverable:
                    errorPayload.details?.recoverable ??
                    errorPayload.recoverable ??
                    true,
                },
                requestId,
              },
            },
            emits: result.emits,
          };
        }
        return {
          ack: {
            data: { accepted: true, operation },
            requestId,
          },
          emits: result.emits,
        };
      },
    );
  }

  private async routeRoomCommand(
    roomId: string,
    operation: 'open_card' | 'play_card' | 'surrender',
    userId: string,
    socketId: string,
    payload: unknown,
  ): Promise<MatchServiceResult | undefined> {
    const localRoom = this.rooms.getRoom(roomId);
    if (localRoom?.mode === 'bot') return undefined;
    if (!this.coordination.available) {
      if (operation === 'open_card' || operation === 'play_card') {
        return this.reject(
          socketId,
          operation,
          roomId,
          'queue_unavailable',
          'Koordinasi pertandingan sedang tidak tersedia. Coba lagi.',
          true,
        );
      }
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              code: 'QUEUE_UNAVAILABLE',
              message: 'Koordinasi pertandingan sedang tidak tersedia.',
            },
          },
        ],
      };
    }
    const route = await this.coordination.getRoomRoute(roomId);
    if (!route || route.instanceId === this.redis.instanceId) return undefined;
    try {
      return await this.router.route<MatchServiceResult>(route.instanceId, {
        operation,
        userId,
        socketId,
        payload,
      });
    } catch (error) {
      this.logger.error(
        `Room command routing failed: ${error instanceof Error ? error.message : String(error)}`,
      );
      if (operation === 'open_card' || operation === 'play_card') {
        return this.reject(
          socketId,
          operation,
          roomId,
          'queue_unavailable',
          'Server pemilik pertandingan tidak merespons. Coba lagi.',
          true,
        );
      }
      return {
        emits: [
          {
            socketId,
            event: SERVER_MATCH_EVENTS.error,
            payload: {
              code: 'QUEUE_UNAVAILABLE',
              message: 'Server pemilik pertandingan tidak merespons.',
            },
          },
        ],
      };
    }
  }

  private async handleRoutedCommand(
    command: RoutedRoomCommand,
  ): Promise<MatchServiceResult | PrivateCommandResult> {
    switch (command.operation) {
      case 'reconnect': {
        const result = this.rooms.reconnectUser(
          command.userId,
          command.socketId,
        );
        if (result.type !== 'active_reconnect') return { emits: [] };
        this.clearDisconnectTimer(result.room.roomId, command.userId);
        return {
          emits: [
            ...this.stateEmits(result.room),
            ...this.emitPresence(result.room).emits,
          ],
        };
      }
      case 'disconnect': {
        const result = this.rooms.disconnectUser(
          command.userId,
          command.socketId,
        );
        if (result.type !== 'active_presence') return { emits: [] };
        this.scheduleDisconnectForfeit(result.room, result.userId);
        return this.emitPresence(result.room);
      }
      case 'open_card':
        return this.handleOpenCard(
          command.userId,
          command.socketId,
          command.payload as OpenCardPayload,
          true,
        );
      case 'play_card':
        return this.handlePlayCard(
          command.userId,
          command.socketId,
          command.payload as PlayCardPayload,
          true,
        );
      case 'surrender':
        return this.handleSurrender(
          command.userId,
          command.socketId,
          command.payload as SurrenderPayload,
          true,
        );
      case 'join_private_room':
        return this.handleJoinPrivateRoom(
          command.userId,
          command.socketId,
          command.payload as JoinPrivateRoomPayload,
          true,
        );
    }
  }

  private scheduleQueueLease(entry: RedisQueueEntry): void {
    this.clearQueueLease(entry.userId);
    const timer = setTimeout(() => {
      void this.refreshQueueLease(entry);
    }, 10_000);
    timer.unref?.();
    this.queueLeaseTimers.set(entry.userId, timer);
  }

  private scheduleRoomCleanup(roomId: string): void {
    this.clearRoomRouteRefresh(roomId);
    const route = this.roomRoutes.get(roomId);
    if (route) {
      this.roomRoutes.delete(roomId);
      void this.coordination.removeRoom(route).catch((error: unknown) => {
        this.logger.error(
          `Failed to remove room route: ${error instanceof Error ? error.message : String(error)}`,
        );
      });
    }
    this.rooms.scheduleCleanup(roomId);
  }

  private clearQueueLease(userId: string): void {
    const timer = this.queueLeaseTimers.get(userId);
    if (timer) clearTimeout(timer);
    this.queueLeaseTimers.delete(userId);
  }

  private scheduleRoomRouteRefresh(route: RoomRoute): void {
    this.clearRoomRouteRefresh(route.roomId);
    const timer = setTimeout(() => {
      void this.refreshRoomRoute(route);
    }, 60_000);
    timer.unref?.();
    this.roomRouteTimers.set(route.roomId, timer);
  }

  private clearRoomRouteRefresh(roomId: string): void {
    const timer = this.roomRouteTimers.get(roomId);
    if (timer) clearTimeout(timer);
    this.roomRouteTimers.delete(roomId);
  }

  private async refreshQueueLease(entry: RedisQueueEntry): Promise<void> {
    this.queueLeaseTimers.delete(entry.userId);
    try {
      if (await this.coordination.refreshQueue(entry)) {
        this.scheduleQueueLease(entry);
      }
    } catch (error) {
      this.logger.error(
        `Failed to refresh queue lease: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private async refreshRoomRoute(route: RoomRoute): Promise<void> {
    this.roomRouteTimers.delete(route.roomId);
    const room = this.rooms.getRoom(route.roomId);
    if (!room || room.status !== 'active') return;
    try {
      if (await this.coordination.registerRoom(route)) {
        this.scheduleRoomRouteRefresh(route);
      }
    } catch (error) {
      this.logger.error(
        `Room route refresh failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private reject(
    socketId: string,
    action: CardActionRejectedPayload['action'],
    roomId: string | undefined,
    reason: string,
    message: string,
    recoverable = true,
  ): MatchServiceResult {
    return {
      emits: [
        {
          socketId,
          event: SERVER_MATCH_EVENTS.cardActionRejected,
          payload: { roomId, action, reason, message, recoverable },
        },
      ],
    };
  }
}
