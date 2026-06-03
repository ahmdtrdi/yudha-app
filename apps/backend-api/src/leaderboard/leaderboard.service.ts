import { Injectable, NotFoundException } from '@nestjs/common';
import { LeaderboardRepository } from './leaderboard.repository';
import type { LeaderboardQuery } from './leaderboard.types';

@Injectable()
export class LeaderboardService {
  private readonly defaultLimit = 50;
  private readonly maxLimit = 100;

  constructor(private readonly repository: LeaderboardRepository) {}

  async list(query: LeaderboardQuery) {
    const limit = this.parseNonNegativeInteger(
      query.limit,
      this.defaultLimit,
      this.maxLimit,
    );
    const offset = this.parseNonNegativeInteger(query.offset, 0);

    return {
      data: await this.repository.list(limit, offset),
      meta: {
        limit,
        offset,
        sort: 'rank_points_desc',
      },
    };
  }

  async getMyRank(userId: string) {
    const entry = await this.repository.getUserRank(userId);

    if (!entry) {
      throw new NotFoundException('Leaderboard profile not found.');
    }

    return {
      data: entry,
    };
  }

  private parseNonNegativeInteger(
    value: string | undefined,
    fallback: number,
    max?: number,
  ): number {
    if (value === undefined) {
      return fallback;
    }

    const parsed = Number(value);

    if (!Number.isInteger(parsed) || parsed < 0) {
      return fallback;
    }

    return max ? Math.min(parsed, max) : parsed;
  }
}
