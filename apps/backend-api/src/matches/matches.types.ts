export interface MatchHistoryEntry {
  id: string;
  roomId: string;
  opponentId: string | null;
  opponentUsername: string | null;
  isBotMatch: boolean;
  outcome: 'win' | 'lose' | 'draw';
  reason: string;
  finalState: {
    hpSelf: number;
    hpOpponent: number;
    scoreSelf: number;
    scoreOpponent: number;
  };
  ratingDelta: number;
  coinsDelta: number;
  completedAt: string;
}

export interface MatchHistoryQuery {
  limit?: string;
  offset?: string;
}
