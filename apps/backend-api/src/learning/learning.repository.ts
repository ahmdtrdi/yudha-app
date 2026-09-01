import {
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import {
  EVIDENCE_CLASSIFICATION_VERSION,
  LEARNING_CALCULATION_VERSION,
} from './learning.constants';
import type { LearningTarget } from './learning.types';

const PAGE_SIZE = 500;

@Injectable()
export class LearningRepository {
  private readonly client: any;

  constructor(supabaseService: SupabaseService) {
    this.client = supabaseService.getClient() as any;
  }

  async getUserTarget(userId: string): Promise<LearningTarget> {
    const result = await this.client
      .from('profiles')
      .select('target')
      .eq('id', userId)
      .single();
    if (result.error || !result.data) {
      if (result.error?.code === 'PGRST116') {
        throw new NotFoundException('Profile not found.');
      }
      this.fail(result.error?.message ?? 'Failed to load learner target.');
    }
    if (!['cpns', 'bumn'].includes(result.data.target)) {
      throw new ConflictException(
        'Learning V2 is unavailable for this target.',
      );
    }
    return result.data.target as LearningTarget;
  }

  async getLatestTaxonomyVersion(): Promise<any | null> {
    const result = await this.client
      .from('learning_taxonomy_versions')
      .select('*')
      .lte('effective_at', new Date().toISOString())
      .order('effective_at', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (result.error) this.fail(result.error.message);
    return result.data ?? null;
  }

  async listSkills(taxonomyVersionId: string, target: LearningTarget) {
    const result = await this.client
      .from('learning_skills')
      .select('*')
      .eq('taxonomy_version_id', taxonomyVersionId)
      .eq('target', target)
      .eq('enabled', true)
      .order('category')
      .order('subcategory')
      .order('skill_id');
    if (result.error) this.fail(result.error.message);
    return result.data ?? [];
  }

  async listAttemptsForSkill(
    userId: string,
    target: LearningTarget,
    taxonomyVersionId: string,
    skillId: string,
  ): Promise<{
    attempts: any[];
    classifications: any[];
    invalidatedAttemptIds: Set<string>;
    invalidatedRevisionIds: Set<string>;
  }> {
    const attempts = await this.allRows(() =>
      this.client
        .from('learning_attempts')
        .select('*')
        .eq('user_id', userId)
        .eq('target', target)
        .eq('source', 'solo')
        .eq('taxonomy_version_id', taxonomyVersionId)
        .eq('skill_id', skillId)
        .order('source_event_at', { ascending: false })
        .order('id', { ascending: false }),
    );
    if (attempts.length === 0) {
      return {
        attempts: [],
        classifications: [],
        invalidatedAttemptIds: new Set(),
        invalidatedRevisionIds: new Set(),
      };
    }
    const attemptIds = attempts.map((row) => row.id);
    const revisionIds = Array.from(
      new Set(
        attempts
          .map((row) => row.question_revision_id)
          .filter((value): value is string => Boolean(value)),
      ),
    );
    const classifications = await this.selectInChunks(
      'learning_attempt_classifications',
      '*',
      'attempt_id',
      attemptIds,
      (query) =>
        query.eq('classification_version', EVIDENCE_CLASSIFICATION_VERSION),
    );
    const attemptInvalidations = await this.selectInChunks(
      'learning_attempt_invalidations',
      'attempt_id',
      'attempt_id',
      attemptIds,
    );
    const revisionInvalidations = await this.selectInChunks(
      'learning_attempt_invalidations',
      'question_revision_id',
      'question_revision_id',
      revisionIds,
    );
    return {
      attempts,
      classifications,
      invalidatedAttemptIds: new Set(
        attemptInvalidations.map((row) => row.attempt_id).filter(Boolean),
      ),
      invalidatedRevisionIds: new Set(
        revisionInvalidations
          .map((row) => row.question_revision_id)
          .filter(Boolean),
      ),
    };
  }

  async getLatestRetention(
    userId: string,
    target: LearningTarget,
    taxonomyVersionId: string,
    skillId: string,
  ): Promise<any | null> {
    const result = await this.client
      .from('retention_schedules')
      .select('*')
      .eq('user_id', userId)
      .eq('target', target)
      .eq('taxonomy_version_id', taxonomyVersionId)
      .eq('skill_id', skillId)
      .eq('calculation_version', LEARNING_CALCULATION_VERSION)
      .order('strong_evidence_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (result.error) this.fail(result.error.message);
    return result.data ?? null;
  }

  async upsertSkillState(row: Record<string, unknown>): Promise<void> {
    const result = await this.client.from('learner_skill_state').upsert(row, {
      onConflict:
        'user_id,target,taxonomy_version_id,skill_id,calculation_version',
    });
    if (result.error) this.fail(result.error.message);
  }

  async upsertRetentionSchedule(row: Record<string, unknown>): Promise<void> {
    const result = await this.client.from('retention_schedules').upsert(row, {
      onConflict:
        'user_id,target,taxonomy_version_id,skill_id,calculation_version,strong_evidence_at',
      ignoreDuplicates: true,
    });
    if (result.error) this.fail(result.error.message);
  }

  async listPreparedStates(
    userId: string,
    target: LearningTarget,
    taxonomyVersionId: string,
  ): Promise<any[]> {
    const result = await this.client
      .from('learner_skill_state')
      .select('*')
      .eq('user_id', userId)
      .eq('target', target)
      .eq('taxonomy_version_id', taxonomyVersionId)
      .eq('calculation_version', LEARNING_CALCULATION_VERSION);
    if (result.error) this.fail(result.error.message);
    return result.data ?? [];
  }

  async inventoryBySkill(
    taxonomyVersionId: string,
    skillIds: string[],
  ): Promise<Map<string, number>> {
    const counts = new Map(skillIds.map((skillId) => [skillId, 0]));
    if (skillIds.length === 0) return counts;
    const mappings = await this.selectInChunks(
      'question_skill_mappings',
      'question_revision_id, skill_id',
      'skill_id',
      skillIds,
      (query) =>
        query
          .eq('taxonomy_version_id', taxonomyVersionId)
          .eq('mapping_type', 'primary'),
    );
    const revisionIds = mappings.map((row) => row.question_revision_id);
    const revisions = await this.selectInChunks(
      'question_revisions',
      'id',
      'id',
      revisionIds,
      (query) =>
        query
          .eq('is_active', true)
          .in('quality_state', ['development', 'approved', 'under_review']),
    );
    const activeIds = new Set(revisions.map((row) => row.id));
    for (const mapping of mappings) {
      if (activeIds.has(mapping.question_revision_id)) {
        counts.set(mapping.skill_id, (counts.get(mapping.skill_id) ?? 0) + 1);
      }
    }
    return counts;
  }

  async getLatestAssessment(userId: string, target: LearningTarget) {
    const result = await this.client
      .from('assessment_evidence')
      .select('*')
      .eq('user_id', userId)
      .eq('target', target)
      .order('occurred_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (result.error) this.fail(result.error.message);
    return result.data ?? null;
  }

  async getActiveRecommendation(userId: string, target: LearningTarget) {
    const now = new Date().toISOString();
    const expired = await this.client
      .from('learning_recommendations')
      .update({ status: 'expired' })
      .eq('user_id', userId)
      .eq('target', target)
      .eq('status', 'active')
      .lte('expires_at', now);
    if (expired.error) this.fail(expired.error.message);
    const result = await this.client
      .from('learning_recommendations')
      .select('*')
      .eq('user_id', userId)
      .eq('target', target)
      .eq('status', 'active')
      .gt('expires_at', now)
      .order('generated_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (result.error) this.fail(result.error.message);
    return result.data ?? null;
  }

  async replaceActiveRecommendation(
    userId: string,
    target: LearningTarget,
    row: Record<string, unknown> | null,
  ): Promise<any | null> {
    const update = await this.client
      .from('learning_recommendations')
      .update({ status: 'superseded' })
      .eq('user_id', userId)
      .eq('target', target)
      .eq('status', 'active');
    if (update.error) this.fail(update.error.message);
    if (!row) return null;
    const insert = await this.client
      .from('learning_recommendations')
      .insert(row)
      .select('*')
      .single();
    if (insert.error || !insert.data) {
      this.fail(insert.error?.message ?? 'Failed to store recommendation.');
    }
    return insert.data;
  }

  async listRetentionSchedules(
    userId: string,
    target: LearningTarget,
    taxonomyVersionId: string,
  ) {
    const result = await this.client
      .from('retention_schedules')
      .select('*')
      .eq('user_id', userId)
      .eq('target', target)
      .eq('taxonomy_version_id', taxonomyVersionId)
      .eq('calculation_version', LEARNING_CALCULATION_VERSION)
      .order('review_due_at', { ascending: true });
    if (result.error) this.fail(result.error.message);
    return result.data ?? [];
  }

  async getActivity(
    userId: string,
    target: LearningTarget,
    startsAt: string,
    endsAt: string,
  ) {
    const rows = await this.allRows(() =>
      this.client
        .from('learning_attempts')
        .select(
          'id, question_revision_id, source, source_session_key, source_event_at, effective_response_time_ms, is_correct',
        )
        .eq('user_id', userId)
        .eq('target', target)
        .gte('source_event_at', startsAt)
        .lte('source_event_at', endsAt)
        .order('source_event_at', { ascending: false }),
    );
    const invalidations = await this.selectInChunks(
      'learning_attempt_invalidations',
      'attempt_id',
      'attempt_id',
      rows.map((row) => row.id),
    );
    const invalidated = new Set(
      invalidations.map((row) => row.attempt_id).filter(Boolean),
    );
    const revisionInvalidations = await this.selectInChunks(
      'learning_attempt_invalidations',
      'question_revision_id',
      'question_revision_id',
      Array.from(
        new Set(
          rows
            .map((row) => row.question_revision_id)
            .filter((value): value is string => Boolean(value)),
        ),
      ),
    );
    const invalidatedRevisions = new Set(
      revisionInvalidations
        .map((row) => row.question_revision_id)
        .filter(Boolean),
    );
    return rows.filter(
      (row) =>
        !invalidated.has(row.id) &&
        !invalidatedRevisions.has(row.question_revision_id),
    );
  }

  async recentSkillAttemptCounts(
    userId: string,
    target: LearningTarget,
    taxonomyVersionId: string,
    asOf: Date,
  ): Promise<Map<string, number>> {
    const startsAt = new Date(asOf.getTime() - 24 * 60 * 60 * 1000);
    const rows = await this.allRows(() =>
      this.client
        .from('learning_attempts')
        .select('id, question_revision_id, skill_id')
        .eq('user_id', userId)
        .eq('target', target)
        .eq('source', 'solo')
        .eq('taxonomy_version_id', taxonomyVersionId)
        .not('skill_id', 'is', null)
        .gte('source_event_at', startsAt.toISOString())
        .lte('source_event_at', asOf.toISOString()),
    );
    const attemptInvalidations = await this.selectInChunks(
      'learning_attempt_invalidations',
      'attempt_id',
      'attempt_id',
      rows.map((row) => row.id),
    );
    const revisionInvalidations = await this.selectInChunks(
      'learning_attempt_invalidations',
      'question_revision_id',
      'question_revision_id',
      Array.from(
        new Set(
          rows
            .map((row) => row.question_revision_id)
            .filter((value): value is string => Boolean(value)),
        ),
      ),
    );
    const invalidatedAttempts = new Set(
      attemptInvalidations.map((row) => row.attempt_id).filter(Boolean),
    );
    const invalidatedRevisions = new Set(
      revisionInvalidations
        .map((row) => row.question_revision_id)
        .filter(Boolean),
    );
    const counts = new Map<string, number>();
    for (const row of rows) {
      if (
        invalidatedAttempts.has(row.id) ||
        invalidatedRevisions.has(row.question_revision_id)
      ) {
        continue;
      }
      counts.set(row.skill_id, (counts.get(row.skill_id) ?? 0) + 1);
    }
    return counts;
  }

  async recordRecommendationEvent(input: {
    recommendationId: string;
    userId: string;
    eventType: 'shown' | 'accepted' | 'dismissed';
    dismissalReason: string | null;
    idempotencyKey: string;
  }): Promise<any> {
    const recommendation = await this.client
      .from('learning_recommendations')
      .select('id, target, status')
      .eq('id', input.recommendationId)
      .eq('user_id', input.userId)
      .single();
    if (recommendation.error || !recommendation.data) {
      if (recommendation.error?.code === 'PGRST116') {
        throw new NotFoundException('Learning recommendation not found.');
      }
      this.fail(
        recommendation.error?.message ?? 'Failed to load recommendation.',
      );
    }
    const existing = await this.client
      .from('recommendation_events')
      .select('*')
      .eq('recommendation_id', input.recommendationId)
      .eq('user_id', input.userId)
      .eq('idempotency_key', input.idempotencyKey)
      .maybeSingle();
    if (existing.error) this.fail(existing.error.message);
    if (existing.data) {
      if (
        existing.data.event_type !== input.eventType ||
        existing.data.dismissal_reason !== input.dismissalReason
      ) {
        throw new ConflictException('IDEMPOTENCY_KEY_REUSED');
      }
      return existing.data;
    }
    const inserted = await this.client
      .from('recommendation_events')
      .insert({
        recommendation_id: input.recommendationId,
        user_id: input.userId,
        event_type: input.eventType,
        dismissal_reason: input.dismissalReason,
        idempotency_key: input.idempotencyKey,
        event_source: 'client',
      })
      .select('*')
      .single();
    if (inserted.error || !inserted.data) {
      if (inserted.error?.code === '23505') {
        const raced = await this.client
          .from('recommendation_events')
          .select('*')
          .eq('recommendation_id', input.recommendationId)
          .eq('user_id', input.userId)
          .eq('idempotency_key', input.idempotencyKey)
          .maybeSingle();
        if (raced.error) this.fail(raced.error.message);
        if (
          raced.data?.event_type === input.eventType &&
          raced.data?.dismissal_reason === input.dismissalReason
        ) {
          return raced.data;
        }
        throw new ConflictException('IDEMPOTENCY_KEY_REUSED');
      }
      this.fail(inserted.error?.message ?? 'Failed to record event.');
    }
    if (input.eventType === 'dismissed') {
      const dismissed = await this.client
        .from('learning_recommendations')
        .update({ status: 'dismissed' })
        .eq('id', input.recommendationId)
        .eq('user_id', input.userId)
        .eq('status', 'active');
      if (dismissed.error) this.fail(dismissed.error.message);
    }
    return inserted.data;
  }

  async enqueueProjection(input: {
    userId: string;
    target: LearningTarget;
    taxonomyVersionId?: string | null;
    skillId?: string | null;
    reason: string;
  }): Promise<void> {
    const result = await this.client.rpc('enqueue_learning_projection', {
      p_user_id: input.userId,
      p_target: input.target,
      p_taxonomy_version_id: input.taxonomyVersionId ?? null,
      p_skill_id: input.skillId ?? null,
      p_reason: input.reason,
      p_source_attempt_id: null,
    });
    if (result.error) this.fail(result.error.message);
  }

  async claimProjectionJobs(workerId: string, limit = 25): Promise<any[]> {
    const result = await this.client.rpc('claim_learning_projection_jobs', {
      p_worker_id: workerId,
      p_limit: limit,
    });
    if (result.error) this.fail(result.error.message);
    return Array.isArray(result.data) ? result.data : [];
  }

  async reconcileRecentPvpEvidence(now: Date): Promise<number> {
    const since = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
    const result = await this.client.rpc(
      'reconcile_recent_pvp_learning_evidence',
      {
        p_since: since.toISOString(),
        p_limit: 100,
      },
    );
    if (result.error) this.fail(result.error.message);
    return Number(result.data?.attemptsInserted ?? 0);
  }

  async completeJobs(jobIds: string[]): Promise<void> {
    if (jobIds.length === 0) return;
    const result = await this.client
      .from('learning_projection_jobs')
      .update({
        status: 'completed',
        locked_at: null,
        locked_by: null,
        last_error: null,
      })
      .in('id', jobIds);
    if (result.error) this.fail(result.error.message);
  }

  async failJobs(jobIds: string[], message: string): Promise<void> {
    if (jobIds.length === 0) return;
    const result = await this.client
      .from('learning_projection_jobs')
      .update({
        status: 'failed',
        available_at: new Date(Date.now() + 60_000).toISOString(),
        locked_at: null,
        locked_by: null,
        last_error: message.slice(0, 1000),
      })
      .in('id', jobIds);
    if (result.error) this.fail(result.error.message);
  }

  async completeQueuedJobsForUser(
    userId: string,
    target: LearningTarget,
  ): Promise<void> {
    const result = await this.client
      .from('learning_projection_jobs')
      .update({
        status: 'completed',
        locked_at: null,
        locked_by: null,
        last_error: null,
      })
      .eq('user_id', userId)
      .eq('target', target)
      .in('status', ['pending', 'failed']);
    if (result.error) this.fail(result.error.message);
  }

  async markDueRetentionAndQueue(now: Date): Promise<number> {
    const due = await this.client
      .from('retention_schedules')
      .select('id, user_id, target, taxonomy_version_id, skill_id')
      .eq('status', 'scheduled')
      .lte('review_due_at', now.toISOString())
      .limit(100);
    if (due.error) this.fail(due.error.message);
    for (const row of due.data ?? []) {
      const updated = await this.client
        .from('retention_schedules')
        .update({ status: 'due' })
        .eq('id', row.id)
        .eq('status', 'scheduled');
      if (updated.error) this.fail(updated.error.message);
      await this.enqueueProjection({
        userId: row.user_id,
        target: row.target,
        taxonomyVersionId: row.taxonomy_version_id,
        skillId: row.skill_id,
        reason: 'retention_due',
      });
    }
    return (due.data ?? []).length;
  }

  async expireRecommendationsAndQueue(now: Date): Promise<number> {
    const expiring = await this.client
      .from('learning_recommendations')
      .select('id, user_id, target, taxonomy_version_id')
      .eq('status', 'active')
      .lte('expires_at', now.toISOString())
      .limit(100);
    if (expiring.error) this.fail(expiring.error.message);
    for (const row of expiring.data ?? []) {
      const updated = await this.client
        .from('learning_recommendations')
        .update({ status: 'expired' })
        .eq('id', row.id)
        .eq('status', 'active');
      if (updated.error) this.fail(updated.error.message);
      await this.enqueueProjection({
        userId: row.user_id,
        target: row.target,
        taxonomyVersionId: row.taxonomy_version_id,
        reason: 'recommendation_expired',
      });
    }
    return (expiring.data ?? []).length;
  }

  private async allRows(build: () => any): Promise<any[]> {
    const rows: any[] = [];
    for (let offset = 0; ; offset += PAGE_SIZE) {
      const result = await build().range(offset, offset + PAGE_SIZE - 1);
      if (result.error) this.fail(result.error.message);
      const page = result.data ?? [];
      rows.push(...page);
      if (page.length < PAGE_SIZE) return rows;
    }
  }

  private async selectInChunks(
    table: string,
    columns: string,
    column: string,
    values: string[],
    configure: (query: any) => any = (query) => query,
  ): Promise<any[]> {
    const rows: any[] = [];
    for (let index = 0; index < values.length; index += 200) {
      const chunk = values.slice(index, index + 200);
      if (chunk.length === 0) continue;
      const result = await configure(
        this.client.from(table).select(columns).in(column, chunk),
      );
      if (result.error) this.fail(result.error.message);
      rows.push(...(result.data ?? []));
    }
    return rows;
  }

  private fail(message: string): never {
    throw new InternalServerErrorException(message);
  }
}
