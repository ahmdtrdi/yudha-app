import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import type { InternalRoomState } from '../engine/battle.types';
import type { MatchLogRpcEntry } from '../logs/match-log.types';

/** Shape returned by the finalize_match_result RPC */
export type FinalizeResult = {
  persisted: boolean;
  reason?: string;
  matchResultId?: string;
  ratingDeltaA?: number;
  ratingDeltaB?: number;
  coinsDeltaA?: number;
  coinsDeltaB?: number;
};

/** Computed deltas attached to the room after persistence */
export type PersistedDeltas = {
  ratingDeltaA: number;
  ratingDeltaB: number;
  coinsDeltaA: number;
  coinsDeltaB: number;
};

@Injectable()
export class MatchResultService {
  private readonly logger = new Logger(MatchResultService.name);
  private static readonly RETRY_DELAY_MS = 500;

  constructor(private readonly supabaseService: SupabaseService) {}

  /**
   * Persist match result to Supabase and update profile stats.
   * Also bulk-inserts buffered match logs if a matchResultId is obtained.
   * Fire-and-forget — logs errors but never throws so Socket.IO flow is not blocked.
   * Returns computed deltas if successful, null otherwise.
   */
  async finalizeMatch(room: InternalRoomState, logEntries: MatchLogRpcEntry[] = []): Promise<PersistedDeltas | null> {
    if (!room.result) {
      this.logger.warn(`finalizeMatch called on room ${room.roomId} with no result`);
      return null;
    }

    const params = this.buildRpcParams(room);

    // First attempt
    let result = await this.callRpc(params, room.roomId);
    if (result) {
      await this.persistLogs(result.matchResultId, logEntries, room.roomId);
      return this.extractDeltas(result);
    }

    // Retry once after delay
    this.logger.warn(`Retrying finalize for room ${room.roomId} after ${MatchResultService.RETRY_DELAY_MS}ms`);
    await this.delay(MatchResultService.RETRY_DELAY_MS);
    result = await this.callRpc(params, room.roomId);
    if (result) {
      await this.persistLogs(result.matchResultId, logEntries, room.roomId);
      return this.extractDeltas(result);
    }

    return null;
  }

  /**
   * Bulk-insert match log entries into `match_logs` using the matchResultId as FK.
   * Runs as a follow-up after the RPC returns the match result ID.
   * Non-blocking — logs errors but doesn't throw.
   */
  private async persistLogs(
    matchResultId: string | undefined,
    logEntries: MatchLogRpcEntry[],
    roomId: string,
  ): Promise<void> {
    if (!matchResultId || logEntries.length === 0) return;

    try {
      const adminClient = this.supabaseService.getAdminClient();
      const rows = logEntries.map((entry) => ({
        match_id: matchResultId,
        user_id: entry.user_id,
        action: entry.action,
        payload: entry.payload,
        created_at: entry.created_at,
      }));

      const { error } = await adminClient.from('match_logs').insert(rows);

      if (error) {
        this.logger.error(
          `MATCH_LOGS_PERSIST_FAILED room=${roomId} matchId=${matchResultId} error=${error.message}`,
        );
      } else {
        this.logger.log(`Match logs persisted: room=${roomId} matchId=${matchResultId} count=${rows.length}`);
      }
    } catch (error) {
      this.logger.error(
        `MATCH_LOGS_PERSIST_FAILED room=${roomId} exception=${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private async callRpc(
    params: Record<string, unknown>,
    roomId: string,
  ): Promise<FinalizeResult | null> {
    try {
      const adminClient = this.supabaseService.getAdminClient();
      const { data, error } = await adminClient.rpc('finalize_match_result', params);

      if (error) {
        this.logger.error(
          `MATCH_PERSIST_FAILED room=${roomId} error=${error.message}`,
          { params, error },
        );
        return null;
      }

      const result = data as FinalizeResult;
      if (result.persisted) {
        this.logger.log(`Match persisted: room=${roomId} id=${result.matchResultId}`);
      } else {
        this.logger.log(`Match already persisted (duplicate): room=${roomId}`);
      }

      return result;
    } catch (error) {
      this.logger.error(
        `MATCH_PERSIST_FAILED room=${roomId} exception=${error instanceof Error ? error.message : String(error)}`,
        { params },
      );
      return null;
    }
  }

  private buildRpcParams(room: InternalRoomState): Record<string, unknown> {
    const { result, players, startedAt, endedAt } = room;
    if (!result) throw new Error('Cannot build RPC params without match result');

    const durationSeconds = endedAt && startedAt
      ? Math.round((endedAt.getTime() - startedAt.getTime()) / 1000)
      : null;

    // Map internal outcome to DB enum values
    const outcome = this.mapOutcome(result, players.playerA.userId, players.playerB.userId);

    return {
      p_room_id: room.roomId,
      p_mode: 'player', // Bot mode will be added when bot battles are implemented
      p_player_a_id: players.playerA.userId,
      p_player_b_id: players.playerB.userId,
      p_winner_user_id: result.winnerUserId,
      p_loser_user_id: result.loserUserId,
      p_outcome: outcome,
      p_reason: result.reason === 'draw' ? 'draw' : result.reason,
      p_player_a_hp: result.finalState.playerA.hp,
      p_player_b_hp: result.finalState.playerB.hp,
      p_player_a_points: result.finalState.playerA.points,
      p_player_b_points: result.finalState.playerB.points,
      p_duration_seconds: durationSeconds,
      p_started_at: startedAt.toISOString(),
    };
  }

  private mapOutcome(
    result: NonNullable<InternalRoomState['result']>,
    playerAUserId: string,
    playerBUserId: string,
  ): 'player_a_win' | 'player_b_win' | 'draw' {
    if (!result.winnerUserId) return 'draw';
    if (result.winnerUserId === playerAUserId) return 'player_a_win';
    if (result.winnerUserId === playerBUserId) return 'player_b_win';
    return 'draw';
  }

  private extractDeltas(result: FinalizeResult): PersistedDeltas {
    return {
      ratingDeltaA: result.ratingDeltaA ?? 0,
      ratingDeltaB: result.ratingDeltaB ?? 0,
      coinsDeltaA: result.coinsDeltaA ?? 0,
      coinsDeltaB: result.coinsDeltaB ?? 0,
    };
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
