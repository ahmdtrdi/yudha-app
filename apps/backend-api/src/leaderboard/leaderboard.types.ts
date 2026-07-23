export interface LeaderboardEntry {
  rank: number;
  userId: string;
  username: string | null;
  rankPoints: number;
  totalMatches: number;
  wins: number;
  losses: number;
  winrate: number;
  equippedAvatarId: string | null;
  equippedArenaId: string | null;
  equippedTowerId: string | null;
}

export interface LeaderboardQuery {
  limit?: string;
  offset?: string;
}
