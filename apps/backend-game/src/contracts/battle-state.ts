import type { PublicQuestionCard } from './question-card';

export type BattleRole = 'playerA' | 'playerB';
export type RoomStatus = 'waiting' | 'active' | 'finished' | 'cancelled';
export type BattlePhase =
  | 'waiting'
  | 'active'
  | 'card_opened'
  | 'round_break'
  | 'finished';
export type BattleOutcome = 'win' | 'lose' | 'draw' | 'surrender';
export type BattleTarget = 'cpns' | 'bumn';
export type MatchmakingMode = 'ranked' | 'casual' | 'bot' | 'private';

export type BattleLoadout = {
  characterId: string;
  towerId: string;
};

export type PublicBattleState = {
  roomId: string;
  status: RoomStatus;
  mode: MatchmakingMode;
  target: BattleTarget;
  self: {
    userId: string;
    displayName: string;
    loadout: BattleLoadout;
    role: BattleRole;
    hp: number;
    points: number;
    comboLevel: number;
    hand: PublicQuestionCard[];
    openedCardId?: string;
    answeredCardIds: string[];
    connected: boolean;
  };
  opponent: {
    userId: string;
    displayName: string;
    loadout: BattleLoadout;
    role: BattleRole;
    hp: number;
    points: number;
    comboLevel: number;
    connected: boolean;
  };
  currentRound: number;
  roundSecondsRemaining: number;
  selfRoundWins: number;
  opponentRoundWins: number;
  lastRoundOutcome?: 'win' | 'lose' | 'draw';
  phase: BattlePhase;
  outcome?: BattleOutcome;
};
