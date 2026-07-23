import { Injectable, Logger } from '@nestjs/common';
import { SERVER_MATCH_EVENTS } from '../../../../contracts/match.events';
import type {
  CardActionRejectedPayload,
  JoinQueuePayload,
  MatchFoundPayload,
  OpenCardPayload,
  PlayCardPayload,
  SurrenderPayload,
} from '../../../../contracts/match.payloads';
import type { MatchmakingMode } from '../../../../contracts/battle-state';
import { GameEngine } from './engine/game-engine';
import type { InternalRoomState } from './engine/battle.types';
import { QuestionService } from './questions/question.service';
import { MatchResultService } from './results/match-result.service';
import { RoomManager } from './rooms/room-manager';
import { MatchLogBuffer } from './logs/match-log-buffer';
import { BotBattleService } from './bot/bot-battle.service';
import { CardTimeoutService } from './timeout/card-timeout.service';
import {
  GamePlayerProfileService,
  type GamePlayerProfile,
} from './profiles/game-player-profile.service';

type ServerMatchEventName =
  (typeof SERVER_MATCH_EVENTS)[keyof typeof SERVER_MATCH_EVENTS];

export type MatchEmit = {
  socketId: string;
  event: ServerMatchEventName;
  payload: unknown;
};

export type MatchServiceResult = {
  emits: MatchEmit[];
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

  constructor(
    private readonly engine: GameEngine,
    private readonly questions: QuestionService,
    private readonly rooms: RoomManager,
    private readonly matchResultService: MatchResultService,
    private readonly logBuffer: MatchLogBuffer,
    private readonly botBattleService: BotBattleService,
    private readonly cardTimeoutService: CardTimeoutService,
    private readonly profiles: GamePlayerProfileService,
  ) {}

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
    });
  }

  registerSocket(socketId: string, userId: string): MatchServiceResult {
    const result = this.rooms.registerSocket(socketId, userId);
    if (result.type !== 'active_reconnect') {
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

  handleDisconnect(socketId: string): MatchServiceResult {
    const result = this.rooms.disconnectSocket(socketId);
    if (result.type === 'queued_removed') {
      return { emits: [] };
    }
    if (result.type === 'active_presence') {
      this.scheduleDisconnectForfeit(result.room, result.userId);
      return this.emitPresence(result.room);
    }
    return { emits: [] };
  }

  async handleJoinQueue(
    userId: string,
    socketId: string,
    payload?: JoinQueuePayload,
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

    const cards = await this.questions.getMatchQuestionPool(profile.target);
    const queueResult = this.rooms.joinQueue(profile, socketId, mode, cards);

    if (queueResult.rejected) {
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

    const emits: MatchEmit[] = [
      {
        socketId,
        event: SERVER_MATCH_EVENTS.queueJoined,
        payload: {
          position: this.rooms.queuePositionFor(
            userId,
            profile.target,
            mode,
          ),
          queueDepth: queueResult.queueDepth,
          mode,
          target: profile.target,
        },
      },
    ];

    if (!queueResult.match) return { emits };

    const { room, playerA, playerB } = queueResult.match;
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

    const room = await this.botBattleService.createBotMatch(profile, socketId);
    const bot = room.players.playerB;
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

  handleCancelQueue(userId: string, socketId: string): MatchServiceResult {
    const removed = this.rooms.cancelQueue(userId);
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

  handleOpenCard(
    userId: string,
    socketId: string,
    payload?: OpenCardPayload,
  ): MatchServiceResult {
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
    payload?: PlayCardPayload,
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
      {
        socketId,
        event: SERVER_MATCH_EVENTS.playCardResult,
        payload: result.playResult,
      },
      ...this.stateEmits(room),
    ];

    if (result.matchResult) {
      this.clearRoundTimers(room.roomId);
      this.botBattleService.cancelBotSchedule(room.roomId);
      this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
      await this.persistAndEnrich(room);
      this.clearDisconnectTimersForRoom(room.roomId);
      emits.push(...this.matchResultEmits(room));
      this.rooms.scheduleCleanup(room.roomId);
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

    const emits: MatchEmit[] = [...this.stateEmits(room)];

    const socketId = this.rooms.getSocketIdForUser(userId);
    if (socketId) {
      emits.unshift({
        socketId,
        event: SERVER_MATCH_EVENTS.playCardResult,
        payload: result.playResult,
      });
    }

    if (result.matchResult) {
      this.clearRoundTimers(room.roomId);
      this.botBattleService.cancelBotSchedule(room.roomId);
      this.cardTimeoutService.cancelAllTimersForRoom(room.roomId);
      await this.persistAndEnrich(room);
      this.clearDisconnectTimersForRoom(room.roomId);
      emits.push(...this.matchResultEmits(room));
      this.rooms.scheduleCleanup(room.roomId);
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
    payload?: SurrenderPayload,
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
    this.rooms.scheduleCleanup(room.roomId);
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
      this.rooms.scheduleCleanup(roomId);
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
        this.rooms
          .listRoomUsers(room)
          .map((userId) => {
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
    this.rooms.scheduleCleanup(room.roomId);
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

  private isMatchmakingMode(value: unknown): value is MatchmakingMode {
    return value === 'ranked' || value === 'casual' || value === 'bot';
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
