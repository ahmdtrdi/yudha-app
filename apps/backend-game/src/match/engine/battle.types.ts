import type { PublicBattleState } from '../../../../../contracts/battle-state';
import type {
  MatchResultPayload,
  MatchResultReason,
  PlayCardResultPayload,
} from '../../../../../contracts/match.payloads';
import type { PublicQuestionCard } from '../../../../../contracts/question-card';
import type { InternalCard } from '../questions/question.types';

export type BattleRole = 'playerA' | 'playerB';
export type RoomStatus = 'waiting' | 'active' | 'finished' | 'cancelled';

export type InternalPlayerState = {
  userId: string;
  socketId: string | null;
  role: BattleRole;
  hp: number;
  points: number;
  hand: InternalCard[];
  openedCardId?: string;
  answeredCardIds: Set<string>;
  nextDrawIndex: number;
  connected: boolean;
};

export type InternalRoomState = {
  roomId: string;
  status: RoomStatus;
  players: {
    playerA: InternalPlayerState;
    playerB: InternalPlayerState;
  };
  sharedQueue: InternalCard[];
  /** Reserve buffer for recycling — pre-fetched questions beyond the initial pool */
  reserveQueue: InternalCard[];
  /** Counter for generating unique card-instance IDs for recycled cards */
  nextRecycleId: number;
  startedAt: Date;
  endedAt?: Date;
  result?: MatchResultPayload;
};

export type OpenCardSuccess = {
  ok: true;
  room: InternalRoomState;
};

export type BattleReject = {
  ok: false;
  reason: string;
  message: string;
  recoverable: boolean;
};

export type PlayCardSuccess = {
  ok: true;
  room: InternalRoomState;
  playResult: PlayCardResultPayload;
  matchResult?: MatchResultPayload;
};

export type SurrenderSuccess = {
  ok: true;
  room: InternalRoomState;
  matchResult: MatchResultPayload;
};

export type BattleActionResult<T> = T | BattleReject;

export type FinishReason = Exclude<MatchResultReason, 'draw'>;

export type PublicStateBuilder = (
  room: InternalRoomState,
  userId: string,
) => PublicBattleState;

export function toPublicCard(card: InternalCard): PublicQuestionCard {
  return {
    id: card.id,
    prompt: card.prompt,
    options: [...card.options],
    weight: card.weight,
    effect: card.effect,
  };
}
