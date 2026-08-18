import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { LeaderboardRepository } from './leaderboard.repository';
import type { LeaderboardQuery } from './leaderboard.types';

@Injectable()
export class LeaderboardService {
  private readonly defaultLimit = 20;
  private readonly maxLimit = 100;

  constructor(private readonly repository: LeaderboardRepository) {}

  async list(query: LeaderboardQuery) {
    const limit = this.parseInteger(
      query.limit,
      this.defaultLimit,
      1,
      this.maxLimit,
    );
    const offset = this.parseInteger(query.offset, 0, 0);

    const page = await this.repository.list(limit, offset);
    return { data: { items: page.items, limit, offset, total: page.total } };
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

  private parseInteger(
    value: string | undefined,
    fallback: number,
    min: number,
    max?: number,
  ): number {
    if (value === undefined) {
      return fallback;
    }

    const parsed = Number(value);

    if (
      !Number.isInteger(parsed) ||
      parsed < min ||
      (max !== undefined && parsed > max)
    ) {
      throw new BadRequestException(
        `${max === undefined ? 'offset' : 'limit'} must be an integer${max === undefined ? ` greater than or equal to ${min}` : ` between ${min} and ${max}`}.`,
      );
    }

    return parsed;
  }
}
