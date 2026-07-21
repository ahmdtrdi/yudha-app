import { Injectable } from '@nestjs/common';
import { GameEngine } from '../engine/game-engine';
import { QuestionDealer } from '../engine/question-dealer';
import type { InternalRoomState } from '../engine/battle.types';
import type { InternalCard } from '../questions/question.types';
import type { DisconnectResult, MatchCreated, QueueEntry } from './room.types';

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

  registerSocket(socketId: string, userId: string): void {
    this.socketToUser.set(socketId, userId);
    const room = this.getRoomForUser(userId);
    const player = room ? this.findPlayer(room, userId) : undefined;
    if (player) {
      player.socketId = socketId;
      player.connected = true;
    }
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
      player.connected = false;
      player.socketId = null;
      return { type: 'active_presence', room, userId };
    }

    return { type: 'none' };
  }

  joinQueue(
    userId: string,
    socketId: string,
    mode: 'ranked' | 'casual',
    cards: InternalCard[],
    reserveCards: InternalCard[] = [],
  ): { queued: QueueEntry; queueDepth: number; match?: MatchCreated; rejected?: string } {
    const existingRoom = this.getRoomForUser(userId);
    if (existingRoom && existingRoom.status === 'active') {
      return {
        queued: { userId, socketId, mode, joinedAt: new Date() },
        queueDepth: this.queue.length,
        rejected: 'already_in_active_room',
      };
    }

    const existingEntry = this.queue.find((entry) => entry.userId === userId);
    if (existingEntry) {
      existingEntry.socketId = socketId;
      return { queued: existingEntry, queueDepth: this.queue.length };
    }

    const queued = { userId, socketId, mode, joinedAt: new Date() };
    const opponentIndex = this.queue.findIndex((entry) => entry.userId !== userId);
    if (opponentIndex === -1) {
      this.queue.push(queued);
      return { queued, queueDepth: this.queue.length };
    }

    const [opponent] = this.queue.splice(opponentIndex, 1);
    const room = this.createRoom(opponent, queued, cards, reserveCards);
    return { queued, queueDepth: this.queue.length, match: { room, playerA: opponent, playerB: queued } };
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

  getSocketIdForUser(userId: string): string | undefined {
    const room = this.getRoomForUser(userId);
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
    reserveCards: InternalCard[] = [],
  ): InternalRoomState {
    const roomId = `room_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const sharedQueue = this.dealer.createSharedQueue(cards);
    const reserveQueue = this.dealer.createSharedQueue(reserveCards);
    const room = this.engine.createRoom(roomId, playerA.userId, playerB.userId, sharedQueue, reserveQueue);
    room.players.playerA.socketId = playerA.socketId;
    room.players.playerB.socketId = playerB.socketId;
    this.rooms.set(roomId, room);
    this.userToRoom.set(playerA.userId, roomId);
    this.userToRoom.set(playerB.userId, roomId);
    return room;
  }

  createBotRoom(
    userId: string,
    socketId: string,
    cards: InternalCard[],
    reserveCards: InternalCard[] = [],
  ): InternalRoomState {
    const roomId = `room_bot_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const sharedQueue = this.dealer.createSharedQueue(cards);
    const reserveQueue = this.dealer.createSharedQueue(reserveCards);
    const room = this.engine.createRoom(roomId, userId, 'bot', sharedQueue, reserveQueue);
    room.players.playerA.socketId = socketId;
    room.players.playerB.socketId = null;
    room.players.playerB.connected = true;
    this.rooms.set(roomId, room);
    this.userToRoom.set(userId, roomId);
    this.userToRoom.set('bot', roomId);
    return room;
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
