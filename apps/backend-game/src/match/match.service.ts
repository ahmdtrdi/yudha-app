import { Injectable } from '@nestjs/common';
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
import { RoomManager } from './rooms/room-manager';

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
  constructor(
    private readonly engine: GameEngine,
    private readonly questions: QuestionService,
    private readonly rooms: RoomManager,
  ) {}

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
      return this.emitPresence(result.room);
    }
    return { emits: [] };
  }

  handleJoinQueue(userId: string, socketId: string, payload?: JoinQueuePayload): MatchServiceResult {
    const mode = payload?.mode ?? 'casual';
    const queueResult = this.rooms.joinQueue(userId, socketId, mode, this.questions.getCards());

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

  handlePlayCard(userId: string, socketId: string, payload: PlayCardPayload): MatchServiceResult {
    const room = this.rooms.getRoom(payload.roomId);
    if (!room) return this.reject(socketId, 'play_card', payload.roomId, 'room_not_found', 'Room not found.');

    const result = this.engine.playCard(room, userId, payload.cardId, payload.selectedOptionIndex);
    if (!result.ok) {
      return this.reject(socketId, 'play_card', payload.roomId, result.reason, result.message, result.recoverable);
    }

    const emits: MatchEmit[] = [
      {
        socketId,
        event: SERVER_MATCH_EVENTS.playCardResult,
        payload: result.playResult,
      },
      ...this.stateEmits(room),
    ];

    if (result.matchResult) {
      emits.push(...this.matchResultEmits(room));
      this.rooms.scheduleCleanup(room.roomId);
    }

    return { emits };
  }

  handleSurrender(userId: string, socketId: string, payload: SurrenderPayload): MatchServiceResult {
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
