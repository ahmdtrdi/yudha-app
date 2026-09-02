import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class PvpAnalyticsRepository {
  private readonly pageSize = 1000;

  constructor(private readonly supabaseService: SupabaseService) {}

  private get client(): any {
    return this.supabaseService.getClient() as any;
  }

  async profile(userId: string): Promise<any | null> {
    const result = await this.client
      .from('profiles')
      .select('id, username, target')
      .eq('id', userId)
      .maybeSingle();
    if (result.error) this.fail(result.error.message);
    return result.data ?? null;
  }

  async rating(userId: string, target: string): Promise<any | null> {
    const result = await this.client
      .from('pvp_ratings')
      .select('rating, rated_matches, wins, losses, draws, last_match_at')
      .eq('user_id', userId)
      .eq('target', target)
      .maybeSingle();
    if (result.error) this.fail(result.error.message);
    return result.data ?? null;
  }

  async leaderboardEntry(userId: string): Promise<any> {
    const result = await this.client.rpc('get_target_leaderboard_rank', {
      p_user_id: userId,
    });
    if (result.error) this.fail(result.error.message);
    return result.data;
  }

  async matches(
    userId: string,
    target: string,
    modes: string[],
    since: string | null,
  ): Promise<any[]> {
    return this.paged('match_results', (query) => {
      let next = query
        .select(
          'id, mode, target, player_a_id, player_b_id, winner_user_id, loser_user_id, outcome, reason, ended_at',
        )
        .eq('target', target)
        .in('mode', modes)
        .or(`player_a_id.eq.${userId},player_b_id.eq.${userId}`)
        .order('ended_at', { ascending: true })
        .order('id', { ascending: true });
      if (since) next = next.gte('ended_at', since);
      return next;
    });
  }

  async attempts(
    userId: string,
    target: string,
    modes: string[],
    since: string | null,
  ): Promise<any[]> {
    return this.paged('learning_attempts', (query) => {
      let next = query
        .select(
          'id, pvp_mode, question_id, question_revision_id, taxonomy_version_id, skill_id, category, subcategory, difficulty, is_correct, timed_out, seen_before, first_attempt, client_active_response_time_ms, effective_response_time_ms, source_event_at, data_fidelity',
        )
        .eq('user_id', userId)
        .eq('target', target)
        .eq('source', 'pvp')
        .in('pvp_mode', modes)
        .order('source_event_at', { ascending: true })
        .order('id', { ascending: true });
      if (since) next = next.gte('source_event_at', since);
      return next;
    });
  }

  async ratingEvents(
    userId: string,
    target: string,
    since: string | null,
  ): Promise<any[]> {
    return this.paged('pvp_rating_events', (query) => {
      let next = query
        .select('rating_delta, rating_after, created_at')
        .eq('user_id', userId)
        .eq('target', target)
        .eq('algorithm_version', 'elo-v1')
        .order('created_at', { ascending: true });
      if (since) next = next.gte('created_at', since);
      return next;
    });
  }

  async invalidatedAttemptIds(attemptIds: string[]): Promise<Set<string>> {
    if (attemptIds.length === 0) return new Set();
    const invalid = new Set<string>();
    for (let index = 0; index < attemptIds.length; index += 500) {
      const result = await this.client
        .from('learning_attempt_invalidations')
        .select('attempt_id')
        .in('attempt_id', attemptIds.slice(index, index + 500));
      if (result.error) this.fail(result.error.message);
      for (const row of result.data ?? []) {
        if (row.attempt_id) invalid.add(row.attempt_id);
      }
    }
    return invalid;
  }

  async inventoryByTopic(
    topics: Array<{ taxonomyVersionId: string; skillId: string }>,
  ): Promise<Map<string, number>> {
    const inventory = new Map<string, number>();
    for (const topic of topics) {
      const key = `${topic.taxonomyVersionId}:${topic.skillId}`;
      const mappings = await this.client
        .from('question_skill_mappings')
        .select('question_revision_id')
        .eq('taxonomy_version_id', topic.taxonomyVersionId)
        .eq('skill_id', topic.skillId)
        .eq('mapping_type', 'primary');
      if (mappings.error) this.fail(mappings.error.message);
      const revisionIds = (mappings.data ?? []).map(
        (row: any) => row.question_revision_id,
      );
      if (revisionIds.length === 0) {
        inventory.set(key, 0);
        continue;
      }
      const revisions = await this.client
        .from('question_revisions')
        .select('id')
        .in('id', revisionIds)
        .eq('is_active', true)
        .in('quality_state', ['development', 'approved', 'under_review']);
      if (revisions.error) this.fail(revisions.error.message);
      inventory.set(key, (revisions.data ?? []).length);
    }
    return inventory;
  }

  private async paged(
    table: string,
    configure: (query: any) => any,
  ): Promise<any[]> {
    const rows: any[] = [];
    for (let offset = 0; ; offset += this.pageSize) {
      const result = await configure(this.client.from(table)).range(
        offset,
        offset + this.pageSize - 1,
      );
      if (result.error) this.fail(result.error.message);
      const page = result.data ?? [];
      rows.push(...page);
      if (page.length < this.pageSize) return rows;
    }
  }

  private fail(message: string): never {
    throw new InternalServerErrorException(message);
  }
}
