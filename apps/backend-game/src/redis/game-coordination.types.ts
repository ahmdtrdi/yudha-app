import type { BattleTarget } from '../contracts/battle-state';
import type { GamePlayerProfile } from '../match/profiles/game-player-profile.service';
import type { PublicMatchmakingMode } from '../match/rooms/room.types';

export type RedisParticipant = GamePlayerProfile & {
  socketId: string;
  instanceId: string;
};

export type RedisQueueEntry = RedisParticipant & {
  mode: PublicMatchmakingMode;
  joinedAt: number;
  expiresAt: number;
};

export type RedisPrivateReservation = {
  code: string;
  owner: RedisParticipant;
  target: BattleTarget;
  createdAt: number;
  expiresAt: number;
};

export type PublicQueueResult =
  | { type: 'queued'; entry: RedisQueueEntry; position: number; depth: number }
  | {
      type: 'matched';
      entry: RedisQueueEntry;
      opponent: RedisQueueEntry;
      matchId: string;
    }
  | { type: 'conflict' }
  | { type: 'unavailable' };

export type CommandClaim =
  | { type: 'claimed'; requestId: string }
  | { type: 'replay'; requestId: string; acknowledgement: unknown }
  | { type: 'conflict'; requestId: string }
  | { type: 'pending'; requestId: string }
  | { type: 'unavailable'; requestId: string };

export type RoomRoute = {
  roomId: string;
  instanceId: string;
  mode: string;
  userIds: string[];
};
