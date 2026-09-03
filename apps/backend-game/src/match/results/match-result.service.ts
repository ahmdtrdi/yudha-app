import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import type { InternalRoomState } from '../engine/battle.types';
import type { MatchLogRpcEntry } from '../logs/match-log.types';

/** Shape returned by the finalize_match_result RPC */
export type FinalizeResult = {
  persisted: boolean;
  reason?: string;
  matchResultId?: string;
  pvpRatingDeltaA?: number | null;
  pvpRatingDeltaB?: number | null;
  pvpRatingAfterA?: number | null;
  pvpRatingAfterB?: number | null;
  coinsDeltaA?: number;
  coinsDeltaB?: number;
  energyDeltaA?: number;
  energyDeltaB?: number;
  energyBalanceAfterA?: number;
  energyBalanceAfterB?: number;
  progressionApplied?: boolean;
};

/** Computed deltas attached to the room after persistence */
export type PersistedDeltas = {
  pvpRatingDeltaA: number | null;
  pvpRatingDeltaB: number | null;
  pvpRatingAfterA: number | null;
  pvpRatingAfterB: number | null;
  coinsDeltaA: number;
  coinsDeltaB: number;
  energyDeltaA?: number;
  energyDeltaB?: number;
  energyBalanceAfterA?: number;
  energyBalanceAfterB?: number;
  progressionApplied: boolean;
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
  async finalizeMatch(
    room: InternalRoomState,
    logEntries: MatchLogRpcEntry[] = [],
  ): Promise<PersistedDeltas | null> {
    if (!room.result) {
      this.logger.warn(
        `finalizeMatch called on room ${room.roomId} with no result`,
      );
      return null;
    }

    const params = this.buildRpcParams(room);

    // First attempt
    let result = await this.callRpc(params, room.roomId);
    if (result) {
      await this.persistLogs(result.matchResultId, logEntries, room.roomId);
      return this.extractDeltas(result, room);
    }

    // Retry once after delay
    this.logger.warn(
      `Retrying finalize for room ${room.roomId} after ${MatchResultService.RETRY_DELAY_MS}ms`,
    );
    await this.delay(MatchResultService.RETRY_DELAY_MS);
    result = await this.callRpc(params, room.roomId);
    if (result) {
      await this.persistLogs(result.matchResultId, logEntries, room.roomId);
      return this.extractDeltas(result, room);
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
        match_result_id: matchResultId,
        player_id: entry.user_id === 'bot' ? null : entry.user_id,
        question_id: this.stringValue(entry.payload.questionId),
        card_id: this.stringValue(entry.payload.cardId),
        action_type: entry.action,
        selected_option_index: this.numberValue(
          entry.payload.selectedOptionIndex,
        ),
        player_answer: this.stringValue(entry.payload.playerAnswer),
        is_correct: this.booleanValue(entry.payload.correct),
        effect: this.effectValue(entry.payload.effect),
        effect_value: this.numberValue(entry.payload.effectValue) ?? 0,
        hp_before: this.numberValue(entry.payload.hpBefore),
        hp_after: this.numberValue(entry.payload.hpAfter),
        opponent_hp_before: this.numberValue(entry.payload.opponentHpBefore),
        opponent_hp_after: this.numberValue(entry.payload.opponentHpAfter),
        points_before: this.numberValue(entry.payload.pointsBefore),
        points_after: this.numberValue(entry.payload.pointsAfter),
        response_time_ms: this.numberValue(entry.payload.responseTimeMs),
        question_revision_id: this.stringValue(
          entry.payload.questionRevisionId,
        ),
        taxonomy_version_id: this.stringValue(
          entry.payload.taxonomyVersionId,
        ),
        skill_id: this.stringValue(entry.payload.skillId),
        category_snapshot: this.stringValue(entry.payload.category),
        subcategory_snapshot: this.stringValue(entry.payload.subcategory),
        difficulty_snapshot: this.stringValue(entry.payload.difficulty),
        expected_time_ms: this.numberValue(entry.payload.expectedTimeMs),
        time_limit_ms: this.numberValue(entry.payload.timeLimitMs),
        opened_at: this.stringValue(entry.payload.openedAt),
        answered_at: this.stringValue(entry.payload.answeredAt),
        action_timestamp: entry.created_at,
        created_at: entry.created_at,
      }));

      const { error } = await adminClient.from('match_logs').insert(rows);

      if (error) {
        this.logger.error(
          `MATCH_LOGS_PERSIST_FAILED room=${roomId} matchId=${matchResultId} error=${error.message}`,
        );
      } else {
        this.logger.log(
          `Match logs persisted: room=${roomId} matchId=${matchResultId} count=${rows.length}`,
        );
        if (this.learningV2Enabled()) {
          await this.ingestLearningEvidence(matchResultId, roomId);
        }
      }
    } catch (error) {
      this.logger.error(
        `MATCH_LOGS_PERSIST_FAILED room=${roomId} exception=${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private async ingestLearningEvidence(
    matchResultId: string,
    roomId: string,
  ): Promise<void> {
    try {
      const adminClient = this.supabaseService.getAdminClient();
      const { data, error } = await adminClient.rpc(
        'ingest_pvp_learning_evidence',
        { p_match_result_id: matchResultId },
      );
      if (error) {
        this.logger.error(
          `PVP_LEARNING_INGEST_FAILED room=${roomId} matchId=${matchResultId} error=${error.message}`,
        );
        return;
      }
      this.logger.log(
        `PvP learning evidence reconciled: room=${roomId} matchId=${matchResultId} inserted=${Number((data as any)?.inserted ?? 0)}`,
      );
    } catch (error) {
      this.logger.error(
        `PVP_LEARNING_INGEST_FAILED room=${roomId} matchId=${matchResultId} exception=${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private learningV2Enabled(): boolean {
    return process.env.LEARNING_V2_ENABLED?.trim().toLowerCase() === 'true';
  }

  private async callRpc(
    params: Record<string, unknown>,
    roomId: string,
  ): Promise<FinalizeResult | null> {
    try {
      const adminClient = this.supabaseService.getAdminClient();
      const { data, error } = await adminClient.rpc(
        'finalize_match_result',
        params,
      );

      if (error) {
        this.logger.error(
          `MATCH_PERSIST_FAILED room=${roomId} error=${error.message}`,
          { params, error },
        );
        return null;
      }

      const result = data as FinalizeResult;
      if (result.persisted) {
        this.logger.log(
          `Match persisted: room=${roomId} id=${result.matchResultId}`,
        );
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
    if (!result)
      throw new Error('Cannot build RPC params without match result');

    const durationSeconds =
      endedAt && startedAt
        ? Math.round((endedAt.getTime() - startedAt.getTime()) / 1000)
        : null;

    const isBotMatch = room.mode === 'bot';

    // Map internal outcome to DB enum values
    const outcome = this.mapOutcome(
      result,
      players.playerA.userId,
      players.playerB.userId,
    );

    return {
      p_room_id: room.roomId,
      p_mode: room.mode,
      p_target: room.target,
      p_player_a_id: players.playerA.userId,
      p_player_b_id: isBotMatch ? null : players.playerB.userId,
      p_winner_user_id:
        isBotMatch && result.winnerUserId === 'bot'
          ? null
          : result.winnerUserId,
      p_loser_user_id:
        isBotMatch && result.loserUserId === 'bot' ? null : result.loserUserId,
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

  private extractDeltas(
    result: FinalizeResult,
    room?: InternalRoomState,
  ): PersistedDeltas {
    const isNormal =
      room?.result?.reason === 'hp_zero' ||
      room?.result?.reason === 'round_timeout' ||
      room?.result?.reason === 'question_exhaustion' ||
      room?.result?.reason === 'draw';
    const isCasualNormal = isNormal && room?.mode === 'casual';
    const coinsDeltaA =
      result.coinsDeltaA !== undefined
        ? result.coinsDeltaA
        : isCasualNormal
          ? 3
          : 0;
    const coinsDeltaB =
      result.coinsDeltaB !== undefined
        ? result.coinsDeltaB
        : isCasualNormal
          ? 3
          : 0;

    return {
      pvpRatingDeltaA: result.pvpRatingDeltaA ?? null,
      pvpRatingDeltaB: result.pvpRatingDeltaB ?? null,
      pvpRatingAfterA: result.pvpRatingAfterA ?? null,
      pvpRatingAfterB: result.pvpRatingAfterB ?? null,
      coinsDeltaA,
      coinsDeltaB,
      energyDeltaA: result.energyDeltaA,
      energyDeltaB: result.energyDeltaB,
      energyBalanceAfterA: result.energyBalanceAfterA,
      energyBalanceAfterB: result.energyBalanceAfterB,
      progressionApplied: result.progressionApplied === true,
    };
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private stringValue(value: unknown): string | null {
    return typeof value === 'string' ? value : null;
  }

  private numberValue(value: unknown): number | null {
    return typeof value === 'number' && Number.isFinite(value) ? value : null;
  }

  private booleanValue(value: unknown): boolean | null {
    return typeof value === 'boolean' ? value : null;
  }

  private effectValue(value: unknown): 'damage' | 'heal' | 'none' {
    return value === 'damage' || value === 'heal' ? value : 'none';
  }
}
