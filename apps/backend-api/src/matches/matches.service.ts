import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import type { MatchHistoryEntry, MatchHistoryQuery } from './matches.types';

@Injectable()
export class MatchesService {
  private readonly logger = new Logger(MatchesService.name);
  private readonly defaultLimit = 20;
  private readonly maxLimit = 50;

  constructor(private readonly supabaseService: SupabaseService) {}

  async getHistory(userId: string, query: MatchHistoryQuery) {
    const limit = this.parseNonNegativeInteger(query.limit, this.defaultLimit, this.maxLimit);
    const offset = this.parseNonNegativeInteger(query.offset, 0);

    const client = this.supabaseService.getClient();

    // match_results is not yet in the generated database.types.ts,
    // so we use an untyped query until the types are regenerated.
    const { data, error } = await (client as any)
      .from('match_results')
      .select('*')
      .or(`player_a_id.eq.${userId},player_b_id.eq.${userId}`)
      .order('ended_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      this.logger.error(`Failed to fetch match history for ${userId}: ${error.message}`);
      throw new InternalServerErrorException('Failed to fetch match history.');
    }

    const entries: MatchHistoryEntry[] = (data ?? []).map((row: Record<string, unknown>) =>
      this.toHistoryDto(row, userId),
    );

    return {
      data: entries,
      meta: {
        limit,
        offset,
        sort: 'ended_at_desc',
      },
    };
  }

  private toHistoryDto(row: Record<string, unknown>, requestingUserId: string): MatchHistoryEntry {
    const playerAId = row.player_a_id as string;
    const playerBId = row.player_b_id as string | null;
    const winnerId = row.winner_user_id as string | null;
    const mode = row.mode as string;

    const normalizedMode =
      mode === 'casual' || mode === 'bot' ? mode : 'ranked';
    const target = row.target === 'bumn' ? 'bumn' : 'cpns';
    const isBotMatch = normalizedMode === 'bot' || playerBId === null;
    const isSelfPlayerA = playerAId === requestingUserId;

    // Derive self-relative outcome
    let outcome: 'win' | 'lose' | 'draw';
    if (!winnerId) {
      outcome = 'draw';
    } else if (winnerId === requestingUserId) {
      outcome = 'win';
    } else {
      outcome = 'lose';
    }

    // Derive opponent info
    const opponentId = isBotMatch ? null : (isSelfPlayerA ? playerBId : playerAId);

    // Build self-relative final state
    const hpSelf = (isSelfPlayerA ? row.player_a_hp : row.player_b_hp) as number;
    const hpOpponent = (isSelfPlayerA ? row.player_b_hp : row.player_a_hp) as number;
    const scoreSelf = (isSelfPlayerA ? row.player_a_points : row.player_b_points) as number;
    const scoreOpponent = (isSelfPlayerA ? row.player_b_points : row.player_a_points) as number;

    // Self-relative deltas
    const ratingDelta = (isSelfPlayerA ? row.rating_delta_a : row.rating_delta_b) as number ?? 0;
    const coinsDelta = (isSelfPlayerA ? row.coins_delta_a : row.coins_delta_b) as number ?? 0;

    return {
      id: row.id as string,
      roomId: row.room_id as string,
      opponentId,
      opponentUsername: isBotMatch ? 'Bot' : null,
      isBotMatch,
      mode: normalizedMode,
      target,
      outcome,
      reason: row.reason as string,
      finalState: {
        hpSelf,
        hpOpponent,
        scoreSelf,
        scoreOpponent,
      },
      ratingDelta,
      coinsDelta,
      completedAt: row.ended_at as string,
    };
  }

  private parseNonNegativeInteger(
    value: string | undefined,
    fallback: number,
    max?: number,
  ): number {
    if (value === undefined) return fallback;
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 0) return fallback;
    return max ? Math.min(parsed, max) : parsed;
  }
}
