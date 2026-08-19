import type { InternalRoomState } from '../engine/battle.types';
import type { BattleLoadout, BattleTarget } from '../../contracts/battle-state';

export type PublicMatchmakingMode = 'ranked' | 'casual';

export type RoomParticipant = {
  userId: string;
  displayName: string;
  target: BattleTarget;
  loadout: BattleLoadout;
  socketId: string;
};

export type QueueEntry = RoomParticipant & {
  mode: PublicMatchmakingMode;
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
  | { type: 'stale_socket'; userId: string }
  | { type: 'none' };

export type SocketRegistrationResult =
  | { type: 'active_reconnect'; room: InternalRoomState; userId: string }
  | { type: 'registered'; userId: string };
