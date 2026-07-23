import { Injectable } from '@nestjs/common';
import { GameEngine } from '../engine/game-engine';
import { QuestionDealer } from '../engine/question-dealer';
import type { InternalRoomState } from '../engine/battle.types';
import type { InternalCard } from '../questions/question.types';
import type { GamePlayerProfile } from '../profiles/game-player-profile.service';
import type {
  DisconnectResult,
  MatchCreated,
  QueueEntry,
  SocketRegistrationResult,
} from './room.types';

@Injectable()
export class RoomManager {
  private readonly queue: QueueEntry[] = [];
  private readonly rooms = new Map<string, InternalRoomState>();
  private readonly userToRoom = new Map<string, string>();
  private readonly socketToUser = new Map<string, string>();
  private readonly cleanupTimers = new Map<string, ReturnType<typeof setTimeout>>();

  constructor(
    private readonly engine: GameEngine,
    private readonly dealer: QuestionDealer,
  ) {}

  registerSocket(socketId: string, userId: string): SocketRegistrationResult {
    this.socketToUser.set(socketId, userId);
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

    const removed = this.removeFromQueue(userId);
    if (removed) return { type: 'queued_removed', userId };

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

  joinQueue(
    profileOrUserId: GamePlayerProfile | string,
    socketId: string,
    mode: 'ranked' | 'casual',
    cards: InternalCard[],
    legacyReserve: InternalCard[] = [],
  ): { queued: QueueEntry; queueDepth: number; match?: MatchCreated; rejected?: string } {
    const profile =
      typeof profileOrUserId === 'string'
        ? this.defaultProfile(profileOrUserId)
        : profileOrUserId;
    const { userId } = profile;
    const existingRoom = this.getRoomForUser(userId);
    if (existingRoom && existingRoom.status === 'active') {
      return {
        queued: { ...profile, socketId, mode, joinedAt: new Date() },
        queueDepth: this.queueDepthFor(profile.target, mode),
        rejected: 'already_in_active_room',
      };
    }

    const existingEntry = this.queue.find((entry) => entry.userId === userId);
    if (existingEntry) {
      existingEntry.socketId = socketId;
      return {
        queued: existingEntry,
        queueDepth: this.queueDepthFor(existingEntry.target, existingEntry.mode),
      };
    }

    const queued: QueueEntry = {
      ...profile,
      socketId,
      mode,
      joinedAt: new Date(),
    };
    const opponentIndex = this.queue.findIndex(
      (entry) =>
        entry.userId !== userId &&
        entry.target === profile.target &&
        entry.mode === mode,
    );
    if (opponentIndex === -1) {
      this.queue.push(queued);
      return {
        queued,
        queueDepth: this.queueDepthFor(profile.target, mode),
      };
    }

    const [opponent] = this.queue.splice(opponentIndex, 1);
    const room = this.createRoom(opponent, queued, [...cards, ...legacyReserve]);
    return {
      queued,
      queueDepth: this.queueDepthFor(profile.target, mode),
      match: { room, playerA: opponent, playerB: queued },
    };
  }

  cancelQueue(userId: string): boolean {
    return this.removeFromQueue(userId);
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
    return player?.socketId ?? this.queue.find((entry) => entry.userId === userId)?.socketId;
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

  private createRoom(
    playerA: QueueEntry,
    playerB: QueueEntry,
    cards: InternalCard[],
  ): InternalRoomState {
    const roomId = `room_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const sharedQueue = this.dealer.createSharedQueue(cards);
    const room = this.engine.createRoom(
      roomId,
      playerA.mode,
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
      ? [
          ...(socketIdOrCards as InternalCard[]),
          ...cardsOrReserve,
        ]
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

  queuePositionFor(
    userId: string,
    target: QueueEntry['target'],
    mode: QueueEntry['mode'],
  ): number {
    const compatible = this.queue.filter(
      (entry) => entry.target === target && entry.mode === mode,
    );
    const index = compatible.findIndex((entry) => entry.userId === userId);
    return index === -1 ? 0 : index + 1;
  }

  private queueDepthFor(
    target: QueueEntry['target'],
    mode: QueueEntry['mode'],
  ): number {
    return this.queue.filter(
      (entry) => entry.target === target && entry.mode === mode,
    ).length;
  }

  private removeFromQueue(userId: string): boolean {
    const index = this.queue.findIndex((entry) => entry.userId === userId);
    if (index === -1) return false;
    this.queue.splice(index, 1);
    return true;
  }

  private findPlayer(room: InternalRoomState, userId: string) {
    return Object.values(room.players).find((player) => player.userId === userId);
  }
}
