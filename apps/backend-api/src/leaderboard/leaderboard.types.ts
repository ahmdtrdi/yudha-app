export interface LeaderboardEntry {
  rank: number;
  userId: string;
  username: string | null;
  rankPoints: number;
  tier: string;
  rankedWins: number;
  totalMatches: number;
  rankedWinRate: number;
}

export interface LeaderboardQuery {
  limit?: string;
  offset?: string;
}
