import { Injectable, InternalServerErrorException } from '@nestjs/common';
import type { Json } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';
import type { LeaderboardEntry } from './leaderboard.types';

@Injectable()
export class LeaderboardRepository {
  constructor(private readonly supabaseService: SupabaseService) {}

  async list(
    limit: number,
    offset: number,
  ): Promise<{ items: LeaderboardEntry[]; total: number }> {
    const { data, error } = await (this.supabaseService.getClient() as any).rpc(
      'get_leaderboard_page',
      { p_limit: limit, p_offset: offset },
    );
    if (error) throw new InternalServerErrorException(error.message);
    const result = this.requireObject(data, 'get_leaderboard_page');
    return {
      items: Array.isArray(result.items)
        ? (result.items as unknown as LeaderboardEntry[])
        : [],
      total: Number(result.total ?? 0),
    };
  }

  async getUserRank(userId: string): Promise<LeaderboardEntry | null> {
    const { data, error } = await (this.supabaseService.getClient() as any).rpc(
      'get_user_leaderboard_rank',
      { p_user_id: userId },
    );
    if (error) throw new InternalServerErrorException(error.message);
    if (data === null) return null;
    return this.requireObject(
      data,
      'get_user_leaderboard_rank',
    ) as unknown as LeaderboardEntry;
  }

  private requireObject(value: Json, operation: string) {
    if (!value || Array.isArray(value) || typeof value !== 'object') {
      throw new InternalServerErrorException(
        `${operation} returned an invalid result.`,
      );
    }
    return value;
  }
}
