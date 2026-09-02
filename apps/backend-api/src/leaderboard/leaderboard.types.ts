export interface LeaderboardEntry {
  rank: number | null;
  userId: string;
  username: string | null;
  pvpRating: number;
  ratedMatches: number;
  rankedWins: number;
  rankedLosses: number;
  rankedDraws: number;
  rankedWinRate: number | null;
  status: 'rated' | 'unrated';
  target?: 'cpns' | 'bumn';
}

export interface LeaderboardPage {
  target: 'cpns' | 'bumn';
  items: LeaderboardEntry[];
  total: number;
}

export interface LeaderboardQuery {
  limit?: string;
  offset?: string;
}
