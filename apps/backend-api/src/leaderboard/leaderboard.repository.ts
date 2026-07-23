import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import type { Database } from '../supabase/database.types';
import type { LeaderboardEntry } from './leaderboard.types';

type ProfileRow = Database['public']['Tables']['profiles']['Row'];

@Injectable()
export class LeaderboardRepository {
  constructor(private readonly supabaseService: SupabaseService) {}

  async list(limit: number, offset: number): Promise<LeaderboardEntry[]> {
    const { data, error } = await this.baseLeaderboardQuery()
      .range(offset, offset + limit - 1)
      .returns<ProfileRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return (data ?? []).map((profile, index) =>
      this.mapProfile(profile, offset + index + 1),
    );
  }

  async getUserRank(userId: string): Promise<LeaderboardEntry | null> {
    const { data, error } = await this.baseLeaderboardQuery().returns<
      ProfileRow[]
    >();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    const index = (data ?? []).findIndex((profile) => profile.id === userId);

    if (index === -1 || !data) {
      return null;
    }

    return this.mapProfile(data[index], index + 1);
  }

  private baseLeaderboardQuery() {
    return this.supabaseService
      .getClient()
      .from('profiles')
      .select(
        [
          'id',
          'username',
          'rank_points',
          'total_matches',
          'wins',
          'losses',
          'winrate',
          'equipped_avatar_id',
          'equipped_arena_id',
          'equipped_tower_id',
        ].join(', '),
      )
      .order('rank_points', { ascending: false })
      .order('wins', { ascending: false })
      .order('winrate', { ascending: false })
      .order('total_matches', { ascending: false })
      .order('id', { ascending: true });
  }

  private mapProfile(profile: ProfileRow, rank: number): LeaderboardEntry {
    return {
      rank,
      userId: profile.id,
      username: profile.username,
      rankPoints: profile.rank_points,
      totalMatches: profile.total_matches,
      wins: profile.wins,
      losses: profile.losses,
      winrate: profile.winrate,
      equippedAvatarId: profile.equipped_avatar_id,
      equippedArenaId: profile.equipped_arena_id,
      equippedTowerId: profile.equipped_tower_id,
    };
  }
}
