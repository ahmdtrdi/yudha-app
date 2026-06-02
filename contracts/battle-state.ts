import type { PublicQuestionCard } from './question-card';

export type BattleRole = 'playerA' | 'playerB';
export type RoomStatus = 'waiting' | 'active' | 'finished' | 'cancelled';
export type BattlePhase = 'waiting' | 'active' | 'card_opened' | 'finished';
export type BattleOutcome = 'win' | 'lose' | 'draw' | 'surrender';

export type PublicBattleState = {
  roomId: string;
  status: RoomStatus;
  self: {
    userId: string;
    role: BattleRole;
    hp: number;
    points: number;
    hand: PublicQuestionCard[];
    openedCardId?: string;
    answeredCardIds: string[];
    connected: boolean;
  };
  opponent: {
    userId: string;
    role: BattleRole;
    hp: number;
    points: number;
    connected: boolean;
  };
  phase: BattlePhase;
  outcome?: BattleOutcome;
};
