import type { InternalRoomState } from '../engine/battle.types';

export type QueueEntry = {
  userId: string;
  socketId: string;
  mode: 'ranked' | 'casual';
  joinedAt: Date;
};

export type MatchCreated = {
  room: InternalRoomState;
  playerA: QueueEntry;
  playerB: QueueEntry;
};

export type DisconnectResult =
  | { type: 'queued_removed'; userId: string }
  | { type: 'active_presence'; room: InternalRoomState; userId: string }
  | { type: 'none' };
