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
import { GameEngine } from './engine/game-engine';
import type { InternalRoomState } from './engine/battle.types';
import { QuestionService } from './questions/question.service';
import { MatchResultService } from './results/match-result.service';
import { RoomManager } from './rooms/room-manager';
import { MatchLogBuffer } from './logs/match-log-buffer';
import { BotBattleService } from './bot/bot-battle.service';

type ServerMatchEventName = (typeof SERVER_MATCH_EVENTS)[keyof typeof SERVER_MATCH_EVENTS];

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
  private readonly logger = new Logger(MatchService.name);
  private emitServer: ((result: MatchServiceResult) => void) | null = null;

  constructor(
    private readonly engine: GameEngine,
    private readonly questions: QuestionService,
    private readonly rooms: RoomManager,
    private readonly matchResultService: MatchResultService,
    private readonly logBuffer: MatchLogBuffer,
    private readonly botBattleService: BotBattleService,
  ) {}

  /**
   * Set by the gateway once the Server instance is available.
   * Enables async bot turns to emit events to clients.
   */
  setEmitServer(callback: (result: MatchServiceResult) => void): void {
    this.emitServer = callback;
    this.botBattleService.setEmitCallback(callback);
  }

  registerSocket(socketId: string, userId: string): void {
    this.rooms.registerSocket(socketId, userId);
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
      // Cancel bot timer if this is a bot match and the human disconnected
      if (this.botBattleService.isBotMatch(result.room)) {
        this.botBattleService.cancelBotSchedule(result.room.roomId);
      }
      return this.emitPresence(result.room);
    }
    return { emits: [] };
  }

  async handleJoinQueue(userId: string, socketId: string, payload?: JoinQueuePayload): Promise<MatchServiceResult> {
    const mode = payload?.mode ?? 'casual';

    // Bot mode: skip queue, create match instantly
    if (mode === 'bot') {
      return this.handleBotMode(userId, socketId);
    }

    // Fetch question pool from Supabase (once per match creation)
    const { active, reserve } = await this.questions.getMatchQuestionPoolWithReserve('cpns');
    const queueResult = this.rooms.joinQueue(userId, socketId, mode, active, reserve);

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
          position: this.positionFor(userId),
          queueDepth: queueResult.queueDepth,
        },
      },
    ];

    if (!queueResult.match) return { emits };

    const { room, playerA, playerB } = queueResult.match;
    const matchFoundA: MatchFoundPayload = {
      roomId: room.roomId,
      opponentUserId: playerB.userId,
      role: 'playerA',
    };
    const matchFoundB: MatchFoundPayload = {
      roomId: room.roomId,
      opponentUserId: playerA.userId,
      role: 'playerB',
    };

    emits.push(
      { socketId: playerA.socketId, event: SERVER_MATCH_EVENTS.matchFound, payload: matchFoundA },
      { socketId: playerB.socketId, event: SERVER_MATCH_EVENTS.matchFound, payload: matchFoundB },
      ...this.stateEmits(room),
    );

    return { emits };
  }

  private async handleBotMode(userId: string, socketId: string): Promise<MatchServiceResult> {
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

    const room = await this.botBattleService.createBotMatch(userId, socketId);

    const matchFound: MatchFoundPayload = {
      roomId: room.roomId,
      opponentUserId: 'bot',
      role: 'playerA',
    };

    return {
      emits: [
        { socketId, event: SERVER_MATCH_EVENTS.matchFound, payload: matchFound },
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

  handleOpenCard(userId: string, socketId: string, payload: OpenCardPayload): MatchServiceResult {
    const room = this.rooms.getRoom(payload.roomId);
    if (!room) return this.reject(socketId, 'open_card', payload.roomId, 'room_not_found', 'Room not found.');

    const result = this.engine.openCard(room, userId, payload.cardId);
    if (!result.ok) {
      return this.reject(socketId, 'open_card', payload.roomId, result.reason, result.message, result.recoverable);
    }

    // Log the open_card action
    this.logBuffer.record(payload.roomId, userId, 'open_card', {
      cardId: payload.cardId,
    });

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

  async handlePlayCard(userId: string, socketId: string, payload: PlayCardPayload): Promise<MatchServiceResult> {
    const room = this.rooms.getRoom(payload.roomId);
    if (!room) return this.reject(socketId, 'play_card', payload.roomId, 'room_not_found', 'Room not found.');

    const result = this.engine.playCard(room, userId, payload.cardId, payload.selectedOptionIndex);
    if (!result.ok) {
      return this.reject(socketId, 'play_card', payload.roomId, result.reason, result.message, result.recoverable);
    }

    // Log the play_card action
    this.logBuffer.record(payload.roomId, userId, 'play_card', {
      cardId: payload.cardId,
      selectedOptionIndex: payload.selectedOptionIndex,
      correct: result.playResult.correct,
      effect: result.playResult.effect,
      effectValue: result.playResult.effectValue,
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
      this.botBattleService.cancelBotSchedule(room.roomId);
      await this.persistAndEnrich(room);
      emits.push(...this.matchResultEmits(room));
      this.rooms.scheduleCleanup(room.roomId);
    }

    return { emits };
  }

  async handleSurrender(userId: string, socketId: string, payload: SurrenderPayload): Promise<MatchServiceResult> {
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
    await this.persistAndEnrich(room);
    this.rooms.scheduleCleanup(room.roomId);
    return { emits: [...this.stateEmits(room), ...this.matchResultEmits(room)] };
  }

  private stateEmits(room: InternalRoomState): MatchEmit[] {
    return this.rooms
      .listRoomUsers(room)
      .map((userId): MatchEmit | undefined => {
        const socketId = this.rooms.getSocketIdForUser(userId);
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
      .map((userId) => this.rooms.getSocketIdForUser(userId))
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
          .map((userId) => [userId, { connected: this.engine.buildPublicState(room, userId).self.connected }]),
      ),
    };
    return {
      emits: this.rooms
        .listRoomUsers(room)
        .map((userId) => this.rooms.getSocketIdForUser(userId))
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
        room.result.finalState.playerA.ratingDelta = deltas.ratingDeltaA;
        room.result.finalState.playerA.coinsDelta = deltas.coinsDeltaA;
        room.result.finalState.playerB.ratingDelta = deltas.ratingDeltaB;
        room.result.finalState.playerB.coinsDelta = deltas.coinsDeltaB;
      }
    } catch (error) {
      this.logger.error(
        `Failed to persist match ${room.roomId}: ${error instanceof Error ? error.message : String(error)}`,
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

  private positionFor(userId: string): number {
    return this.rooms.getRoomForUser(userId) ? 0 : 1;
  }
}
