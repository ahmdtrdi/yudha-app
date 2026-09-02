import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import type { Json } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';
import type { LeaderboardEntry, LeaderboardPage } from './leaderboard.types';

@Injectable()
export class LeaderboardRepository {
  constructor(private readonly supabaseService: SupabaseService) {}

  async list(
    userId: string,
    limit: number,
    offset: number,
  ): Promise<LeaderboardPage> {
    const { data, error } = await (this.supabaseService.getClient() as any).rpc(
      'get_target_leaderboard_page',
      { p_user_id: userId, p_limit: limit, p_offset: offset },
    );
    if (error) this.fail(error.message);
    const result = this.requireObject(data, 'get_target_leaderboard_page');
    return {
      target: result.target as LeaderboardPage['target'],
      items: Array.isArray(result.items)
        ? (result.items as unknown as LeaderboardEntry[])
        : [],
      total: Number(result.total ?? 0),
    };
  }

  async getUserRank(userId: string): Promise<LeaderboardEntry> {
    const { data, error } = await (this.supabaseService.getClient() as any).rpc(
      'get_target_leaderboard_rank',
      { p_user_id: userId },
    );
    if (error) this.fail(error.message);
    if (data === null) {
      throw new InternalServerErrorException(
        'get_target_leaderboard_rank returned no profile.',
      );
    }
    return this.requireObject(
      data,
      'get_target_leaderboard_rank',
    ) as unknown as LeaderboardEntry;
  }

  private fail(message: string): never {
    if (message.includes('TARGET_REQUIRED')) {
      throw new ConflictException({
        code: 'TARGET_REQUIRED',
        message: 'Choose a learning target before viewing the leaderboard.',
      });
    }
    throw new InternalServerErrorException(message);
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
