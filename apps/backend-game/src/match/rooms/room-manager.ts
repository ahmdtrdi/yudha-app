import { Injectable } from '@nestjs/common';
import { GameEngine } from '../engine/game-engine';
import { QuestionDealer } from '../engine/question-dealer';
import type { InternalRoomState } from '../engine/battle.types';
import type { GamePlayerProfile } from '../profiles/game-player-profile.service';
import type {
  DisconnectResult,
  PublicMatchmakingMode,
  RoomParticipant,
  SocketRegistrationResult,
} from './room.types';
import type { InternalCard } from '../questions/question.types';

@Injectable()
export class RoomManager {
  private readonly rooms = new Map<string, InternalRoomState>();
  private readonly userToRoom = new Map<string, string>();
  private readonly socketToUser = new Map<string, string>();
  private readonly cleanupTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();

  constructor(
    private readonly engine: GameEngine,
    private readonly dealer: QuestionDealer,
  ) {}

  registerSocket(socketId: string, userId: string): SocketRegistrationResult {
    this.socketToUser.set(socketId, userId);
    return this.reconnectUser(userId, socketId);
  }

  reconnectUser(userId: string, socketId: string): SocketRegistrationResult {
    const room = this.getRoomForUser(userId);
    const player = room ? this.findPlayer(room, userId) : undefined;
    if (player) {
      if (player.socketId && player.socketId !== socketId) {
        this.socketToUser.delete(player.socketId);
      }
      player.socketId = socketId;
      player.connected = true;
      player.reconnectDeadline = undefined;
      return { type: 'active_reconnect', room: room!, userId };
    }
    return { type: 'registered', userId };
  }

  disconnectSocket(socketId: string): DisconnectResult {
    const userId = this.socketToUser.get(socketId);
    if (!userId) return { type: 'none' };
    this.socketToUser.delete(socketId);

    return this.disconnectUser(userId, socketId);
  }

  disconnectUser(userId: string, socketId: string): DisconnectResult {
    const room = this.getRoomForUser(userId);
    const player = room ? this.findPlayer(room, userId) : undefined;
    if (room && player) {
      if (player.socketId !== socketId) {
        return { type: 'stale_socket', userId };
      }
      player.connected = false;
      player.socketId = null;
      return { type: 'active_presence', room, userId };
    }

    return { type: 'none' };
  }

  getRoom(roomId: string): InternalRoomState | undefined {
    return this.rooms.get(roomId);
  }

  getRoomForUser(userId: string): InternalRoomState | undefined {
    const roomId = this.userToRoom.get(userId);
    return roomId ? this.rooms.get(roomId) : undefined;
  }

  getUserIdForSocket(socketId: string): string | undefined {
    return this.socketToUser.get(socketId);
  }

  getSocketIdForUser(
    userId: string,
    sourceRoom?: InternalRoomState,
  ): string | undefined {
    const room = sourceRoom ?? this.getRoomForUser(userId);
    const player = room ? this.findPlayer(room, userId) : undefined;
    return player?.socketId ?? undefined;
  }

  listRoomUsers(room: InternalRoomState): string[] {
    return [room.players.playerA.userId, room.players.playerB.userId];
  }

  scheduleCleanup(roomId: string, delayMs = 2_000): void {
    if (this.cleanupTimers.has(roomId)) return;
    const timer = setTimeout(() => this.destroyRoom(roomId), delayMs);
    this.cleanupTimers.set(roomId, timer);
  }

  destroyRoom(roomId: string): void {
    const room = this.rooms.get(roomId);
    if (!room) return;
    for (const userId of this.listRoomUsers(room)) {
      this.userToRoom.delete(userId);
    }
    this.rooms.delete(roomId);
    const timer = this.cleanupTimers.get(roomId);
    if (timer) clearTimeout(timer);
    this.cleanupTimers.delete(roomId);
  }

  createPrivateRoom(
    playerA: RoomParticipant,
    playerB: RoomParticipant,
    cards: InternalCard[],
  ): InternalRoomState {
    return this.createHumanRoom(playerA, playerB, 'private', cards);
  }

  createPublicRoom(
    playerA: RoomParticipant,
    playerB: RoomParticipant,
    mode: PublicMatchmakingMode,
    cards: InternalCard[],
  ): InternalRoomState {
    return this.createHumanRoom(playerA, playerB, mode, cards);
  }

  private createHumanRoom(
    playerA: RoomParticipant,
    playerB: RoomParticipant,
    mode: PublicMatchmakingMode | 'private',
    cards: InternalCard[],
  ): InternalRoomState {
    const roomId = `room_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const sharedQueue = this.dealer.createSharedQueue(cards);
    const room = this.engine.createRoom(
      roomId,
      mode,
      playerA.target,
      playerA,
      playerB,
      sharedQueue,
    );
    room.players.playerA.socketId = playerA.socketId;
    room.players.playerB.socketId = playerB.socketId;
    this.rooms.set(roomId, room);
    this.userToRoom.set(playerA.userId, roomId);
    this.userToRoom.set(playerB.userId, roomId);
    return room;
  }

  createBotRoom(
    player: GamePlayerProfile,
    bot: GamePlayerProfile,
    socketId: string,
    cards: InternalCard[],
  ): InternalRoomState;
  createBotRoom(
    playerUserId: string,
    socketId: string,
    cards: InternalCard[],
    legacyReserve?: InternalCard[],
  ): InternalRoomState;
  createBotRoom(
    playerOrUserId: GamePlayerProfile | string,
    botOrSocketId: GamePlayerProfile | string,
    socketIdOrCards: string | InternalCard[],
    cardsOrReserve: InternalCard[] = [],
  ): InternalRoomState {
    const legacy = typeof playerOrUserId === 'string';
    const player = legacy
      ? this.defaultProfile(playerOrUserId)
      : playerOrUserId;
    const bot = legacy
      ? {
          ...this.defaultProfile('bot'),
          displayName: 'BOT YUDHA',
        }
      : (botOrSocketId as GamePlayerProfile);
    const socketId = legacy
      ? (botOrSocketId as string)
      : (socketIdOrCards as string);
    const cards = legacy
      ? [...(socketIdOrCards as InternalCard[]), ...cardsOrReserve]
      : cardsOrReserve;
    const roomId = `room_bot_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const sharedQueue = this.dealer.createSharedQueue(cards);
    const room = this.engine.createRoom(
      roomId,
      'bot',
      player.target,
      player,
      bot,
      sharedQueue,
    );
    room.players.playerA.socketId = socketId;
    room.players.playerB.socketId = null;
    room.players.playerB.connected = true;
    this.rooms.set(roomId, room);
    this.userToRoom.set(player.userId, roomId);
    return room;
  }

  private defaultProfile(userId: string): GamePlayerProfile {
    return {
      userId,
      displayName: userId,
      target: 'cpns',
      loadout: {
        characterId: 'character-basic-squire',
        towerId: 'tower-garda-biru',
      },
    };
  }

  private findPlayer(room: InternalRoomState, userId: string) {
    return Object.values(room.players).find(
      (player) => player.userId === userId,
    );
  }
}
