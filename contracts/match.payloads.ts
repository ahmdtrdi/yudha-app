import type { BattleRole, PublicBattleState } from './battle-state';
import type { CardEffect } from './question-card';

export type JoinQueuePayload = {
  mode?: 'ranked' | 'casual' | 'bot';
};

export type QueueJoinedPayload = {
  position: number;
  queueDepth: number;
};

export type QueueCancelledPayload = {
  reason: 'cancelled' | 'disconnected';
};

export type MatchFoundPayload = {
  roomId: string;
  opponentUserId: string;
  role: BattleRole;
};

export type OpenCardPayload = {
  roomId: string;
  cardId: string;
};

export type OpenCardAcceptedPayload = {
  roomId: string;
  cardId: string;
};

export type PlayCardPayload = {
  roomId: string;
  cardId: string;
  selectedOptionIndex: number;
};

export type PlayCardResultPayload = {
  roomId: string;
  cardId: string;
  correct: boolean;
  effect: CardEffect | 'none';
  effectValue: number;
};

export type CardActionRejectedPayload = {
  roomId?: string;
  action: 'open_card' | 'play_card';
  reason: string;
  message: string;
  recoverable: boolean;
};

export type SurrenderPayload = {
  roomId: string;
};

export type MatchResultReason =
  | 'hp_zero'
  | 'surrender'
  | 'question_exhaustion'
  | 'draw';

export type MatchResultPayload = {
  roomId: string;
  outcome: 'win' | 'lose' | 'draw' | 'surrender';
  winnerUserId: string | null;
  loserUserId: string | null;
  reason: MatchResultReason;
  finalState: {
    playerA: {
      userId: string;
      hp: number;
      points: number;
      ratingDelta?: number;
      coinsDelta?: number;
    };
    playerB: {
      userId: string;
      hp: number;
      points: number;
      ratingDelta?: number;
      coinsDelta?: number;
    };
  };
};

export type PresenceUpdatePayload = {
  roomId: string;
  players: Record<string, { connected: boolean }>;
};

export type MatchGatewayEvents = {
  queue_joined: QueueJoinedPayload;
  queue_cancelled: QueueCancelledPayload;
  match_found: MatchFoundPayload;
  game_state_update: PublicBattleState;
  open_card_accepted: OpenCardAcceptedPayload;
  card_action_rejected: CardActionRejectedPayload;
  play_card_result: PlayCardResultPayload;
  match_result: MatchResultPayload;
  presence_update: PresenceUpdatePayload;
  error: { message: string };
};
