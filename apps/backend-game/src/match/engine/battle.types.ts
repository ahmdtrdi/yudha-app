import type {
  BattleLoadout,
  BattleTarget,
  MatchmakingMode,
  PublicBattleState,
} from '../../contracts/battle-state';
import type {
  MatchResultPayload,
  MatchResultReason,
  PlayCardResultPayload,
} from '../../contracts/match.payloads';
import type { PublicQuestionCard } from '../../contracts/question-card';
import type { InternalCard } from '../questions/question.types';

export type BattleRole = 'playerA' | 'playerB';
export type RoomStatus = 'waiting' | 'active' | 'finished' | 'cancelled';

export type BattlePlayerSeed = {
  userId: string;
  displayName: string;
  loadout: BattleLoadout;
};

export type InternalCategoryDeckState = {
  category: string;
  /** The ten-card working buffer used for immediate replacement draws. */
  buffer: InternalCard[];
  /** Questions that have not entered the working buffer yet. */
  reserve: InternalCard[];
  /** Original category pool, used only as a safety fallback if content is short. */
  source: InternalCard[];
  /** Number of cards from this category cast during the current round. */
  castCount: number;
  /** Maximum casts allowed for this category during one round. */
  castLimit: number;
};

export type InternalPlayerState = {
  userId: string;
  displayName: string;
  loadout: BattleLoadout;
  socketId: string | null;
  role: BattleRole;
  hp: number;
  points: number;
  comboLevel: number;
  comboExpiresAt?: Date;
  hand: InternalCard[];
  openedCardId?: string;
  openedCardAt?: Date;
  answeredCardIds: Set<string>;
  categoryDecks?: Record<string, InternalCategoryDeckState>;
  connected: boolean;
  reconnectDeadline?: Date;
};

export type InternalRoomState = {
  roomId: string;
  status: RoomStatus;
  mode: MatchmakingMode;
  target: BattleTarget;
  players: {
    playerA: InternalPlayerState;
    playerB: InternalPlayerState;
  };
  sharedQueue: InternalCard[];
  /** Reserve buffer for recycling — pre-fetched questions beyond the initial pool */
  reserveQueue: InternalCard[];
  /** Counter for generating unique card-instance IDs for recycled cards */
  nextRecycleId: number;
  currentRound: number;
  playerARoundWins: number;
  playerBRoundWins: number;
  roundStatus: 'active' | 'break';
  roundEndsAt?: Date;
  nextRoundAt?: Date;
  lastRoundWinnerUserId?: string | null;
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
    category: card.category,
    subcategory: card.subcategory,
    timeLimitSeconds: card.timeLimitSeconds,
    isExhausted: card.isExhausted,
  };
}
