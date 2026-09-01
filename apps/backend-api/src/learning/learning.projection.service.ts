import { Injectable, Logger } from '@nestjs/common';
import {
  calculateSkillState,
  rankRecommendation,
} from './learning.calculators';
import {
  EVIDENCE_CLASSIFICATION_VERSION,
  LEARNING_CALCULATION_VERSION,
  LEARNING_RECOMMENDATION_TTL_MS,
  LEARNING_REVIEW_DELAY_DAYS,
} from './learning.constants';
import { LearningRepository } from './learning.repository';
import type {
  ClassifiedAttempt,
  EvidenceClassification,
  LearningAttemptEvidence,
  LearningTarget,
  RecommendationCandidate,
  SkillStateProjection,
} from './learning.types';

const DAY_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class LearningProjectionService {
  private readonly logger = new Logger(LearningProjectionService.name);

  constructor(private readonly repository: LearningRepository) {}

  async rebuildUserTarget(
    userId: string,
    target: LearningTarget,
    asOf = new Date(),
    requestedSkillIds?: string[],
  ): Promise<void> {
    const taxonomy = await this.repository.getLatestTaxonomyVersion();
    if (!taxonomy) {
      this.logger.warn(
        `Projection skipped for ${userId}/${target}: taxonomy unavailable.`,
      );
      return;
    }
    const skills = await this.repository.listSkills(taxonomy.id, target);
    const requested = requestedSkillIds?.length
      ? new Set(requestedSkillIds)
      : null;
    const affectedSkills = requested
      ? skills.filter((skill) => requested.has(skill.skill_id))
      : skills;

    for (const skill of affectedSkills) {
      await this.rebuildSkill(
        userId,
        target,
        taxonomy.id,
        skill.skill_id,
        asOf,
      );
    }

    const states = await this.repository.listPreparedStates(
      userId,
      target,
      taxonomy.id,
    );
    const stateBySkill = new Map(
      states.map((state) => [state.skill_id, stateFromRow(state)]),
    );
    const [inventory, assessment, retentionRows, recentCounts] =
      await Promise.all([
        this.repository.inventoryBySkill(
          taxonomy.id,
          skills.map((skill) => skill.skill_id),
        ),
        this.repository.getLatestAssessment(userId, target),
        this.repository.listRetentionSchedules(userId, target, taxonomy.id),
        this.repository.recentSkillAttemptCounts(
          userId,
          target,
          taxonomy.id,
          asOf,
        ),
      ]);
    const assessmentBySkill = assessmentSkillAccuracy(assessment);
    const retentionBySkill = latestRetentionBySkill(retentionRows);
    const candidates: RecommendationCandidate[] = skills.map((skill) => {
      const state = stateBySkill.get(skill.skill_id) ?? emptyState();
      return {
        taxonomyVersionId: taxonomy.id,
        skillId: skill.skill_id,
        skillLabel: skill.label,
        category: skill.category,
        subcategory: skill.subcategory,
        curriculumWeight: Number(skill.curriculum_weight),
        isRequired: Boolean(skill.is_required),
        inventoryCount: inventory.get(skill.skill_id) ?? 0,
        state,
        assessmentAccuracy: assessmentBySkill.get(skill.skill_id) ?? null,
        attemptsLast24Hours: recentCounts.get(skill.skill_id) ?? 0,
        reviewDue:
          state.status === 'needs_review' ||
          retentionBySkill.get(skill.skill_id)?.status === 'due',
        retentionAccuracy: nullableNumber(
          retentionBySkill.get(skill.skill_id)?.retention_accuracy,
        ),
      };
    });
    const ranked = rankRecommendation(candidates, asOf);
    await this.repository.replaceActiveRecommendation(
      userId,
      target,
      ranked
        ? {
            user_id: userId,
            target,
            taxonomy_version_id: taxonomy.id,
            calculation_version: LEARNING_CALCULATION_VERSION,
            evidence_classification_version: EVIDENCE_CLASSIFICATION_VERSION,
            objective: ranked.objective,
            mechanic_mode: ranked.mechanicMode,
            question_selection_type: ranked.questionSelectionType,
            skill_ids: [ranked.candidate.skillId],
            availability_runnable: ranked.availability.runnable,
            availability_reason: ranked.availability.reason,
            execution_adapter: ranked.availability.executionAdapter,
            reason_headline: reasonHeadline(
              ranked.objective,
              ranked.candidate.skillLabel,
            ),
            reason_description: reasonDescription(ranked.candidate),
            reason_evidence: ranked.reasonEvidence,
            input_as_of: asOf.toISOString(),
            input_snapshot: {
              priority: ranked.priority,
              inventoryCount: ranked.candidate.inventoryCount,
              state: ranked.candidate.state,
              assessmentAccuracy: ranked.candidate.assessmentAccuracy,
            },
            generated_at: asOf.toISOString(),
            expires_at: new Date(
              asOf.getTime() + LEARNING_RECOMMENDATION_TTL_MS,
            ).toISOString(),
            status: 'active',
          }
        : null,
    );
  }

  async rebuildAndDrainUser(
    userId: string,
    target?: LearningTarget,
    asOf = new Date(),
  ): Promise<void> {
    const resolvedTarget =
      target ?? (await this.repository.getUserTarget(userId));
    await this.rebuildUserTarget(userId, resolvedTarget, asOf);
    await this.repository.completeQueuedJobsForUser(userId, resolvedTarget);
  }

  async drain(limit = 25, asOf = new Date()): Promise<number> {
    const workerId = `backend-api:${process.pid}`;
    const jobs = await this.repository.claimProjectionJobs(workerId, limit);
    if (jobs.length === 0) return 0;
    const grouped = new Map<
      string,
      { jobs: any[]; userId: string; target: LearningTarget }
    >();
    for (const job of jobs) {
      const key = `${job.user_id}:${job.target}`;
      const group: {
        jobs: any[];
        userId: string;
        target: LearningTarget;
      } = grouped.get(key) ?? {
        jobs: [],
        userId: job.user_id,
        target: job.target as LearningTarget,
      };
      group.jobs.push(job);
      grouped.set(key, group);
    }
    for (const group of grouped.values()) {
      const jobIds = group.jobs.map((job) => job.id);
      try {
        const includesFullRebuild = group.jobs.some(
          (job) => !job.taxonomy_version_id || !job.skill_id,
        );
        const skillIds = includesFullRebuild
          ? undefined
          : Array.from(new Set(group.jobs.map((job) => job.skill_id)));
        await this.rebuildUserTarget(
          group.userId,
          group.target,
          asOf,
          skillIds,
        );
        await this.repository.completeJobs(jobIds);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : 'Unknown projection error';
        await this.repository.failJobs(jobIds, message);
        this.logger.error(
          `Projection failed for ${group.userId}/${group.target}: ${message}`,
        );
      }
    }
    return jobs.length;
  }

  private async rebuildSkill(
    userId: string,
    target: LearningTarget,
    taxonomyVersionId: string,
    skillId: string,
    asOf: Date,
  ) {
    const [evidence, retention] = await Promise.all([
      this.repository.listAttemptsForSkill(
        userId,
        target,
        taxonomyVersionId,
        skillId,
      ),
      this.repository.getLatestRetention(
        userId,
        target,
        taxonomyVersionId,
        skillId,
      ),
    ]);
    const classificationByAttempt = new Map(
      evidence.classifications.map((row) => [row.attempt_id, row]),
    );
    const attempts = evidence.attempts.reduce<ClassifiedAttempt[]>(
      (values, row) => {
        const classification = classificationByAttempt.get(row.id);
        if (!classification) return values;
        values.push({
          attempt: attemptFromRow(row),
          classification: classificationFromRow(row, classification),
          invalidated:
            evidence.invalidatedAttemptIds.has(row.id) ||
            (row.question_revision_id
              ? evidence.invalidatedRevisionIds.has(row.question_revision_id)
              : false),
        });
        return values;
      },
      [],
    );
    const retentionInput = retention
      ? {
          strongEvidenceAt: retention.strong_evidence_at,
          reviewDueAt: retention.review_due_at,
          reviewDue:
            retention.status === 'due' ||
            (retention.status === 'scheduled' &&
              Date.parse(retention.review_due_at) <= asOf.getTime()),
          retentionCorrectCount: Number(retention.retention_correct_count),
          retentionAttemptCount: Number(retention.retention_attempt_count),
          retentionAccuracy: nullableNumber(retention.retention_accuracy),
        }
      : null;
    const state = calculateSkillState({
      attempts,
      retention: retentionInput,
      asOf,
    });
    await this.repository.upsertSkillState({
      user_id: userId,
      target,
      taxonomy_version_id: taxonomyVersionId,
      skill_id: skillId,
      calculation_version: LEARNING_CALCULATION_VERSION,
      evidence_classification_version: EVIDENCE_CLASSIFICATION_VERSION,
      status: state.status,
      activity_correct_count: state.activityCorrectCount,
      activity_attempt_count: state.activityAttemptCount,
      activity_accuracy: state.activityAccuracy,
      independent_correct_count: state.independentCorrectCount,
      independent_attempt_count: state.independentAttemptCount,
      independent_accuracy: state.independentAccuracy,
      unseen_correct_count: state.unseenCorrectCount,
      unseen_attempt_count: state.unseenAttemptCount,
      unique_question_count: state.uniqueQuestionCount,
      unseen_independent_accuracy: state.unseenIndependentAccuracy,
      smoothed_accuracy: state.smoothedAccuracy,
      assisted_correct_count: state.assistedCorrectCount,
      assisted_attempt_count: state.assistedAttemptCount,
      assisted_accuracy: state.assistedAccuracy,
      hint_rate: state.hintRate,
      independence_gap: state.independenceGap,
      evidence_confidence: state.evidenceConfidence,
      difficulty_level_count: state.difficultyLevelCount,
      median_response_time_ms: state.medianResponseTimeMs,
      pace_ratio: state.paceRatio,
      pace_baseline_type: state.paceBaselineType,
      pace_attempt_count: state.paceAttemptCount,
      timeout_rate: state.timeoutRate,
      trend_percentage_points: state.trendPercentagePoints,
      coverage_sufficient: state.coverageSufficient,
      recommended_mechanic: state.recommendedMechanic,
      latest_eligible_at: state.latestEligibleAt,
      last_practiced_at: state.lastPracticedAt,
      latest_strong_evidence_at: state.latestStrongEvidenceAt,
      input_as_of: asOf.toISOString(),
      attempt_watermark: state.lastPracticedAt,
      updated_at: asOf.toISOString(),
    });
    if (
      state.smoothedAccuracy !== null &&
      state.smoothedAccuracy >= 85 &&
      state.evidenceConfidence !== 'low' &&
      state.latestEligibleAt
    ) {
      await this.repository.upsertRetentionSchedule({
        user_id: userId,
        target,
        taxonomy_version_id: taxonomyVersionId,
        skill_id: skillId,
        calculation_version: LEARNING_CALCULATION_VERSION,
        strong_evidence_at: state.latestEligibleAt,
        review_due_at: new Date(
          Date.parse(state.latestEligibleAt) +
            LEARNING_REVIEW_DELAY_DAYS * DAY_MS,
        ).toISOString(),
        status: 'scheduled',
      });
    }
    return state;
  }
}

function attemptFromRow(row: any): LearningAttemptEvidence {
  return {
    id: row.id,
    source: row.source,
    userId: row.user_id,
    target: row.target,
    questionId: row.question_id,
    questionRevisionId: row.question_revision_id,
    taxonomyVersionId: row.taxonomy_version_id,
    skillId: row.skill_id,
    difficulty: row.difficulty,
    requestedMechanicMode: row.requested_mechanic_mode,
    effectiveMechanicMode: row.effective_mechanic_mode,
    selectedOptionIndex: row.selected_option_index,
    isCorrect: row.is_correct,
    hintRequested: row.hint_requested,
    timedOut: row.timed_out,
    firstAttempt: row.first_attempt,
    seenBefore: row.seen_before,
    expectedTimeMs: row.expected_time_ms,
    standardTimeLimitMs: row.standard_time_limit_ms,
    clientActiveResponseTimeMs: row.client_active_response_time_ms,
    serverElapsedTimeMs: row.server_elapsed_time_ms,
    backgroundDurationMs: row.background_duration_ms,
    effectiveResponseTimeMs: row.effective_response_time_ms,
    timingInvalidityReason: row.timing_invalidity_reason,
    sourceEventAt: row.source_event_at,
  };
}

function classificationFromRow(attempt: any, row: any): EvidenceClassification {
  return {
    classificationVersion: row.classification_version,
    validForActivityAccuracy: row.valid_for_activity_accuracy,
    validForIndependentAccuracy: row.valid_for_independent_accuracy,
    validForUnseenIndependentAccuracy:
      row.valid_for_unseen_independent_accuracy,
    validForAssistedAccuracy: row.valid_for_assisted_accuracy,
    validForPaceAnalytics: row.valid_for_pace_analytics,
    validForFluencyBaseline: row.valid_for_fluency_baseline,
    validForRetention: row.valid_for_retention,
    effectiveResponseTimeMs: attempt.effective_response_time_ms,
    exclusionReasons: row.exclusion_reasons ?? [],
  };
}

export function stateFromRow(row: any): SkillStateProjection {
  return {
    status: row.status,
    activityCorrectCount: Number(row.activity_correct_count),
    activityAttemptCount: Number(row.activity_attempt_count),
    activityAccuracy: nullableNumber(row.activity_accuracy),
    independentCorrectCount: Number(row.independent_correct_count),
    independentAttemptCount: Number(row.independent_attempt_count),
    independentAccuracy: nullableNumber(row.independent_accuracy),
    unseenCorrectCount: Number(row.unseen_correct_count),
    unseenAttemptCount: Number(row.unseen_attempt_count),
    uniqueQuestionCount: Number(row.unique_question_count),
    unseenIndependentAccuracy: nullableNumber(row.unseen_independent_accuracy),
    smoothedAccuracy: nullableNumber(row.smoothed_accuracy),
    assistedCorrectCount: Number(row.assisted_correct_count),
    assistedAttemptCount: Number(row.assisted_attempt_count),
    assistedAccuracy: nullableNumber(row.assisted_accuracy),
    hintRate: nullableNumber(row.hint_rate),
    independenceGap: nullableNumber(row.independence_gap),
    evidenceConfidence: row.evidence_confidence,
    difficultyLevelCount: Number(row.difficulty_level_count ?? 0),
    medianResponseTimeMs: nullableNumber(row.median_response_time_ms),
    paceRatio: nullableNumber(row.pace_ratio),
    paceBaselineType: row.pace_baseline_type,
    paceAttemptCount: Number(row.pace_attempt_count),
    timeoutRate: nullableNumber(row.timeout_rate),
    trendPercentagePoints: nullableNumber(row.trend_percentage_points),
    coverageSufficient: Boolean(row.coverage_sufficient),
    recommendedMechanic: row.recommended_mechanic,
    latestEligibleAt: row.latest_eligible_at,
    lastPracticedAt: row.last_practiced_at,
    latestStrongEvidenceAt: row.latest_strong_evidence_at,
  };
}

export function emptyState(): SkillStateProjection {
  return {
    status: 'collecting_data',
    activityCorrectCount: 0,
    activityAttemptCount: 0,
    activityAccuracy: null,
    independentCorrectCount: 0,
    independentAttemptCount: 0,
    independentAccuracy: null,
    unseenCorrectCount: 0,
    unseenAttemptCount: 0,
    uniqueQuestionCount: 0,
    unseenIndependentAccuracy: null,
    smoothedAccuracy: null,
    assistedCorrectCount: 0,
    assistedAttemptCount: 0,
    assistedAccuracy: null,
    hintRate: null,
    independenceGap: null,
    evidenceConfidence: 'low',
    difficultyLevelCount: 0,
    medianResponseTimeMs: null,
    paceRatio: null,
    paceBaselineType: null,
    paceAttemptCount: 0,
    timeoutRate: null,
    trendPercentagePoints: null,
    coverageSufficient: false,
    recommendedMechanic: 'standard',
    latestEligibleAt: null,
    lastPracticedAt: null,
    latestStrongEvidenceAt: null,
  };
}

function assessmentSkillAccuracy(assessment: any | null): Map<string, number> {
  const values = new Map<string, number>();
  if (!assessment || !Array.isArray(assessment.skill_breakdown)) return values;
  for (const entry of assessment.skill_breakdown) {
    if (
      entry &&
      typeof entry.skillId === 'string' &&
      typeof entry.accuracy === 'number'
    ) {
      values.set(entry.skillId, entry.accuracy);
    }
  }
  return values;
}

function latestRetentionBySkill(rows: any[]): Map<string, any> {
  const values = new Map<string, any>();
  for (const row of [...rows].sort((left, right) =>
    String(right.strong_evidence_at).localeCompare(
      String(left.strong_evidence_at),
    ),
  )) {
    if (!values.has(row.skill_id)) values.set(row.skill_id, row);
  }
  return values;
}

function reasonHeadline(objective: string, skillLabel: string): string {
  const prefix: Record<string, string> = {
    repair_accuracy: 'Perbaiki akurasi',
    spaced_review: 'Saatnya meninjau ulang',
    collect_evidence: 'Kumpulkan bukti belajar',
    build_fluency: 'Bangun kelancaran',
    maintain_coverage: 'Jaga pemerataan latihan',
  };
  return `${prefix[objective] ?? 'Lanjutkan latihan'}: ${skillLabel}`;
}

function reasonDescription(candidate: RecommendationCandidate): string {
  const metric = candidate.state.unseenIndependentAccuracy;
  if (metric === null) {
    return `Data untuk ${candidate.skillLabel} masih dikumpulkan dari soal mandiri yang belum pernah dilihat.`;
  }
  return `${candidate.skillLabel} memiliki akurasi mandiri soal baru ${metric}% dari ${candidate.state.unseenAttemptCount} percobaan dengan keyakinan ${candidate.state.evidenceConfidence}.`;
}

function nullableNumber(value: unknown): number | null {
  return value === null || value === undefined ? null : Number(value);
}
