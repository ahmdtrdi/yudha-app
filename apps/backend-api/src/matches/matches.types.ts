export interface MatchHistoryEntry {
  id: string;
  roomId: string;
  opponentId: string | null;
  opponentUsername: string | null;
  isBotMatch: boolean;
  mode: 'ranked' | 'casual' | 'bot' | 'private';
  target: 'cpns' | 'bumn';
  outcome: 'win' | 'lose' | 'draw';
  reason: string;
  finalState: {
    hpSelf: number;
    hpOpponent: number;
    scoreSelf: number;
    scoreOpponent: number;
  };
  pvpRatingDelta: number | null;
  pvpRatingAfter: number | null;
  coinsDelta: number;
  completedAt: string;
}

export interface MatchHistoryQuery {
  limit?: string;
  offset?: string;
}
