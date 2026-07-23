import type {
  BattleLoadout,
  BattleRole,
  BattleTarget,
  MatchmakingMode,
  PublicBattleState,
} from './battle-state';
import type { CardEffect } from './question-card';

export type JoinQueuePayload = {
  mode?: MatchmakingMode;
};

export type QueueJoinedPayload = {
  position: number;
  queueDepth: number;
  mode: MatchmakingMode;
  target: BattleTarget;
};

export type QueueCancelledPayload = {
  reason: 'cancelled' | 'disconnected';
};

export type MatchFoundPayload = {
  roomId: string;
  opponentUserId: string;
  opponentDisplayName: string;
  opponentLoadout: BattleLoadout;
  role: BattleRole;
  mode: MatchmakingMode;
  target: BattleTarget;
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
  actorUserId: string;
  cardId: string;
  correct: boolean;
  effect: CardEffect | 'none';
  effectValue: number;
  projectileLevel: number;
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
  | 'round_timeout'
  | 'surrender'
  | 'question_exhaustion'
  | 'disconnect'
  | 'draw';

export type MatchResultPayload = {
  roomId: string;
  mode: MatchmakingMode;
  target: BattleTarget;
  outcome: 'win' | 'lose' | 'draw' | 'surrender';
  winnerUserId: string | null;
  loserUserId: string | null;
  reason: MatchResultReason;
  progressionPersisted?: boolean;
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
  players: Record<
    string,
    { connected: boolean; reconnectDeadline?: string }
  >;
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
