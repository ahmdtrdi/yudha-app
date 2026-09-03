import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { asNumber, rankTier } from '../progression/progression.utils';
import { confidence, curriculumCoverage } from './learning.calculators';
import {
  LEARNING_CALCULATION_VERSION,
  learningV2Enabled,
} from './learning.constants';
import { emptyState, stateFromRow } from './learning.projection.service';
import { LearningRepository } from './learning.repository';
import type { RecommendationEventDto } from './dto/recommendation-event.dto';
import type {
  EvidenceConfidence,
  LearningTarget,
  SkillStateProjection,
} from './learning.types';

const DAY_MS = 24 * 60 * 60 * 1000;
const DISMISSAL_REASONS = new Set([
  'prefer_another_skill',
  'too_difficult',
  'too_easy',
  'not_enough_time',
  'do_not_like_timed_mode',
  'other',
]);

@Injectable()
export class LearningService {
  constructor(private readonly repository: LearningRepository) {}

  isEnabled(): boolean {
    return learningV2Enabled();
  }

  async getDashboard(userId: string, window = '30d') {
    this.assertEnabled();
    if (window !== '30d') {
      throw new BadRequestException('window must be 30d.');
    }
    const asOf = new Date();
    const startsAt = wibWindowStart(asOf, 30);
    const target = await this.repository.getUserTarget(userId);
    const taxonomy = await this.repository.getLatestTaxonomyVersion();
    if (!taxonomy) {
      return {
        data: emptyDashboard(target, startsAt, asOf.toISOString()),
      };
    }
    const [
      skills,
      prepared,
      recommendation,
      retention,
      assessments,
      activity,
      profile,
    ] = await Promise.all([
      this.repository.listSkills(taxonomy.id, target),
      this.repository.listPreparedStates(userId, target, taxonomy.id),
      this.repository.getActiveRecommendation(userId, target),
      this.repository.listRetentionSchedules(userId, target, taxonomy.id),
      this.repository.listAssessmentEvidence(userId, target),
      this.repository.getActivity(userId, target, startsAt, asOf.toISOString()),
      this.repository.getLearningProfile(userId),
    ]);
    const rowBySkill = new Map(prepared.map((row) => [row.skill_id, row]));
    const states = skills.map((skill) => {
      const row = rowBySkill.get(skill.skill_id);
      return {
        skill,
        state: row ? stateFromRow(row) : emptyState(),
        inputAsOf: row?.input_as_of ?? asOf.toISOString(),
      };
    });
    const coverage = curriculumCoverage(
      states.map(({ skill, state }) => ({
        isRequired: Boolean(skill.is_required),
        enabled: Boolean(skill.enabled),
        uniqueQuestionCount: state.uniqueQuestionCount,
      })),
    );
    const totalCorrect = states.reduce(
      (sum, entry) => sum + entry.state.unseenCorrectCount,
      0,
    );
    const totalAttempts = states.reduce(
      (sum, entry) => sum + entry.state.unseenAttemptCount,
      0,
    );
    const totalUniqueQuestions = states.reduce(
      (sum, entry) => sum + entry.state.uniqueQuestionCount,
      0,
    );
    const evidenceConfidence = conservativeConfidence(
      states
        .filter((entry) => entry.state.unseenAttemptCount > 0)
        .map((entry) => entry.state.evidenceConfidence),
    );
    const soloActivity = activity.filter((entry) => entry.source === 'solo');
    const competitionActivity = activity.filter(
      (entry) => entry.source === 'pvp',
    );
    const recommendationSkill = recommendation
      ? skills.find((skill) => skill.skill_id === recommendation.skill_ids?.[0])
      : null;
    const skillLabels = new Map<string, string>(
      skills.map((skill) => [String(skill.skill_id), String(skill.label)]),
    );
    const learningAccuracy = metric(
      totalCorrect,
      totalAttempts,
      totalUniqueQuestions,
      evidenceConfidence,
      asOf.toISOString(),
    );

    return {
      data: {
        asOf: asOf.toISOString(),
        calculationVersion: LEARNING_CALCULATION_VERSION,
        target,
        window: {
          type: 'rolling',
          days: 30,
          startsAt,
          endsAt: asOf.toISOString(),
        },
        nextAction: recommendation
          ? toRecommendation(recommendation, recommendationSkill)
          : null,
        summary: {
          curriculumCoverage: {
            value: coverage.coveragePercentage,
            coveredSkillCount: coverage.coveredSkillCount,
            requiredSkillCount: coverage.requiredSkillCount,
            confidence:
              coverage.requiredSkillCount === 0 ? 'low' : evidenceConfidence,
            asOf: asOf.toISOString(),
          },
          unseenIndependentAccuracy: learningAccuracy,
          pace: aggregatePace(states, asOf.toISOString()),
        },
        skillStates: states.map(({ skill, state, inputAsOf }) => ({
          skillId: skill.skill_id,
          label: skill.label,
          category: skill.category,
          subcategory: skill.subcategory,
          required: Boolean(skill.is_required),
          status: state.status,
          evidenceConfidence: state.evidenceConfidence,
          unseenIndependentAccuracy: metric(
            state.unseenCorrectCount,
            state.unseenAttemptCount,
            state.uniqueQuestionCount,
            state.evidenceConfidence,
            inputAsOf,
          ),
          smoothedAccuracy: state.smoothedAccuracy,
          assistedAccuracy: metric(
            state.assistedCorrectCount,
            state.assistedAttemptCount,
            state.uniqueQuestionCount,
            state.evidenceConfidence,
            inputAsOf,
          ),
          hintRate: state.hintRate,
          medianResponseTimeMs: state.medianResponseTimeMs,
          paceRatio: state.paceRatio,
          paceBaselineType: state.paceBaselineType,
          paceAttemptCount: state.paceAttemptCount,
          timeoutRate: state.timeoutRate,
          trendPercentagePoints: state.trendPercentagePoints,
          coverageSufficient: state.coverageSufficient,
          recommendedMechanic: state.recommendedMechanic,
          lastPracticedAt: state.lastPracticedAt,
          asOf: inputAsOf,
        })),
        trends: states
          .filter((entry) => entry.state.trendPercentagePoints !== null)
          .map((entry) => ({
            skillId: entry.skill.skill_id,
            label: entry.skill.label,
            latestAttemptCount: 10,
            previousAttemptCount: 10,
            valuePercentagePoints: entry.state.trendPercentagePoints,
            asOf: entry.inputAsOf,
          })),
        retention: retention.map((row) => ({
          skillId: row.skill_id,
          label: skillLabels.get(String(row.skill_id)) ?? String(row.skill_id),
          strongEvidenceAt: row.strong_evidence_at,
          reviewDueAt: row.review_due_at,
          status:
            row.status === 'scheduled' &&
            Date.parse(row.review_due_at) <= asOf.getTime()
              ? 'due'
              : row.status,
          correctCount: Number(row.retention_correct_count),
          attemptCount: Number(row.retention_attempt_count),
          accuracy: nullableNumber(row.retention_accuracy),
          confidence: 'low' as EvidenceConfidence,
          asOf: row.updated_at ?? row.strong_evidence_at,
        })),
        assessment: assessmentSummary(assessments),
        activity: activitySummary(
          soloActivity,
          startsAt,
          asOf.toISOString(),
          profile,
          skillLabels,
        ),
        competition: competitionSummary(
          competitionActivity,
          startsAt,
          asOf.toISOString(),
          profile,
          learningAccuracy,
        ),
      },
    };
  }

  async getCurrentRecommendation(userId: string) {
    this.assertEnabled();
    const target = await this.repository.getUserTarget(userId);
    const taxonomy = await this.repository.getLatestTaxonomyVersion();
    const recommendation = await this.repository.getActiveRecommendation(
      userId,
      target,
    );
    if (!recommendation || !taxonomy) return { data: null };
    const skills = await this.repository.listSkills(taxonomy.id, target);
    const skill = skills.find(
      (entry) => entry.skill_id === recommendation.skill_ids?.[0],
    );
    return { data: toRecommendation(recommendation, skill) };
  }

  async getLearningNextAction(userId: string) {
    if (!this.isEnabled()) return null;
    const result = await this.getCurrentRecommendation(userId);
    return result.data;
  }

  async getLobbySummary(userId: string) {
    if (!this.isEnabled()) {
      return { curriculumCoverage: null, nextAction: null };
    }

    const target = await this.repository.getUserTarget(userId);
    const taxonomy = await this.repository.getLatestTaxonomyVersion();
    if (!taxonomy) {
      return { curriculumCoverage: null, nextAction: null };
    }

    const [skills, prepared, recommendation] = await Promise.all([
      this.repository.listSkills(taxonomy.id, target),
      this.repository.listPreparedStates(userId, target, taxonomy.id),
      this.repository.getActiveRecommendation(userId, target),
    ]);
    const rowBySkill = new Map(prepared.map((row) => [row.skill_id, row]));
    const states = skills.map((skill) => ({
      skill,
      state: rowBySkill.has(skill.skill_id)
        ? stateFromRow(rowBySkill.get(skill.skill_id))
        : emptyState(),
    }));
    const coverage = curriculumCoverage(
      states.map(({ skill, state }) => ({
        isRequired: Boolean(skill.is_required),
        enabled: Boolean(skill.enabled),
        uniqueQuestionCount: state.uniqueQuestionCount,
      })),
    );
    const evidenceConfidence = conservativeConfidence(
      states
        .filter(({ state }) => state.unseenAttemptCount > 0)
        .map(({ state }) => state.evidenceConfidence),
    );
    const recommendationSkill = recommendation
      ? skills.find((skill) => skill.skill_id === recommendation.skill_ids?.[0])
      : null;

    return {
      curriculumCoverage: {
        value: coverage.coveragePercentage,
        coveredSkillCount: coverage.coveredSkillCount,
        requiredSkillCount: coverage.requiredSkillCount,
        confidence:
          coverage.requiredSkillCount === 0 ? 'low' : evidenceConfidence,
      },
      nextAction: recommendation
        ? toRecommendation(recommendation, recommendationSkill)
        : null,
    };
  }

  async recordRecommendationEvent(
    userId: string,
    recommendationId: string,
    input: RecommendationEventDto,
  ) {
    this.assertEnabled();
    const idempotencyKey = requiredText(
      input.idempotencyKey,
      'idempotencyKey',
      160,
    );
    if (!['shown', 'accepted', 'dismissed'].includes(input.eventType)) {
      throw new BadRequestException('Unsupported recommendation eventType.');
    }
    const dismissalReason = input.dismissalReason ?? null;
    if (
      input.eventType === 'dismissed' &&
      (!dismissalReason || !DISMISSAL_REASONS.has(dismissalReason))
    ) {
      throw new BadRequestException(
        'A supported dismissalReason is required for dismissal.',
      );
    }
    if (input.eventType !== 'dismissed' && dismissalReason !== null) {
      throw new BadRequestException(
        'dismissalReason is only allowed for dismissal.',
      );
    }
    const event = await this.repository.recordRecommendationEvent({
      recommendationId,
      userId,
      eventType: input.eventType,
      dismissalReason,
      idempotencyKey,
    });
    return {
      data: {
        recommendationId,
        eventType: event.event_type,
        dismissalReason: event.dismissal_reason,
        occurredAt: event.occurred_at,
      },
    };
  }

  private assertEnabled(): void {
    if (!this.isEnabled()) {
      throw new ServiceUnavailableException('LEARNING_V2_DISABLED');
    }
  }
}

function toRecommendation(row: any, skill: any | null | undefined) {
  return {
    recommendationId: row.id,
    generatedAt: row.generated_at,
    expiresAt: row.expires_at,
    calculationVersion: row.calculation_version,
    evidenceClassificationVersion: row.evidence_classification_version,
    target: row.target,
    objective: row.objective,
    skill: {
      id: row.skill_ids?.[0] ?? null,
      label: skill?.label ?? row.skill_ids?.[0] ?? null,
      category: skill?.category ?? null,
      subcategory: skill?.subcategory ?? null,
    },
    mechanicMode: row.mechanic_mode,
    questionSelection: {
      type: row.question_selection_type,
      skillIds: row.skill_ids,
    },
    reason: {
      headline: row.reason_headline,
      description: row.reason_description,
      evidence: row.reason_evidence,
    },
    confidence: row.reason_evidence?.[0]?.confidence ?? 'low',
    availability: {
      runnable: row.availability_runnable,
      reason: row.availability_reason,
      compatibilityAdapter: row.execution_adapter,
      label:
        row.execution_adapter === 'practice_fixed_five'
          ? 'Practice 5 soal (kompatibilitas)'
          : null,
    },
  };
}

function metric(
  correctCount: number,
  attemptCount: number,
  uniqueQuestionCount: number,
  confidence: EvidenceConfidence,
  asOf: string,
) {
  return {
    value:
      attemptCount === 0
        ? null
        : Number(((correctCount / attemptCount) * 100).toFixed(2)),
    correctCount,
    attemptCount,
    uniqueQuestionCount,
    confidence,
    asOf,
  };
}

function conservativeConfidence(
  values: EvidenceConfidence[],
): EvidenceConfidence {
  if (values.length === 0 || values.includes('low')) return 'low';
  return values.includes('medium') ? 'medium' : 'high';
}

function aggregatePace(
  states: Array<{ state: SkillStateProjection }>,
  asOf: string,
) {
  const comparable = states
    .map((entry) => entry.state)
    .filter((state) => state.paceRatio !== null && state.paceAttemptCount > 0);
  const ratios = comparable
    .map((state) => state.paceRatio!)
    .sort((a, b) => a - b);
  const middle = Math.floor(ratios.length / 2);
  const value =
    ratios.length === 0
      ? null
      : ratios.length % 2
        ? ratios[middle]
        : Number(((ratios[middle - 1] + ratios[middle]) / 2).toFixed(4));
  return {
    value,
    baselineType:
      comparable.length === 0
        ? null
        : comparable.every((state) => state.paceBaselineType === 'calibrated')
          ? 'calibrated'
          : 'personal',
    attemptCount: comparable.reduce(
      (sum, state) => sum + state.paceAttemptCount,
      0,
    ),
    confidence: conservativeConfidence(
      comparable.map((state) => state.evidenceConfidence),
    ),
    asOf,
  };
}

function activitySummary(
  rows: any[],
  startsAt: string,
  endsAt: string,
  profile?: any,
  skillLabels: Map<string, string> = new Map(),
) {
  const measured = rows
    .map((row) => nullableNumber(row.effective_response_time_ms))
    .filter((value): value is number => value !== null);
  const dailyHistory = dailyActivity(rows, endsAt);
  return {
    window: { days: 30, startsAt, endsAt },
    activeLearningDays: new Set(rows.map((row) => wibDate(row.source_event_at)))
      .size,
    questionsAnswered: rows.length,
    activeLearningMinutes:
      measured.length === 0
        ? null
        : Number(
            (measured.reduce((sum, value) => sum + value, 0) / 60_000).toFixed(
              2,
            ),
          ),
    sessionCount: new Set(
      rows.map((row) => row.source_session_key).filter(Boolean),
    ).size,
    streak: {
      current: asNumber(profile?.current_streak),
      best: asNumber(profile?.best_streak),
      lastDate: profile?.last_streak_date ?? null,
    },
    dailyHistory,
    weeklyActivity: weeklyActivity(dailyHistory),
    recentSessions: recentSessions(rows, skillLabels),
  };
}

function competitionSummary(
  rows: any[],
  startsAt: string,
  endsAt: string,
  profile?: any,
  soloAccuracy?: ReturnType<typeof metric>,
) {
  const resolved = rows.filter((row) => typeof row.is_correct === 'boolean');
  const correct = resolved.filter((row) => row.is_correct).length;
  const accuracyValue =
    resolved.length === 0
      ? null
      : Number(((correct / resolved.length) * 100).toFixed(2));
  const wins = asNumber(profile?.wins);
  const losses = asNumber(profile?.losses);
  const draws = asNumber(profile?.draws);
  const totalMatches = wins + losses + draws;
  const uniqueQuestionCount = new Set(
    resolved.map((row) => row.question_revision_id).filter(Boolean),
  ).size;
  const pvpConfidence = confidence({
    attemptCount: resolved.length,
    uniqueQuestionCount,
    difficultyLevelCount: new Set(
      resolved
        .map((row) => row.difficulty ?? row.effective_difficulty_level)
        .filter(Boolean),
    ).size,
    latestEligibleAt: resolved[0]?.source_event_at ?? null,
    asOf: new Date(endsAt),
  });
  const comparisonEligible =
    accuracyValue !== null &&
    pvpConfidence !== 'low' &&
    soloAccuracy?.value !== null &&
    soloAccuracy?.confidence !== 'low';
  return {
    separateEvidenceContext: true,
    window: { days: 30, startsAt, endsAt },
    accuracy: {
      value: accuracyValue,
      correctCount: correct,
      attemptCount: resolved.length,
      uniqueQuestionCount,
      confidence: pvpConfidence,
      asOf: endsAt,
    },
    rankPoints: asNumber(profile?.rank_points),
    tier: rankTier(asNumber(profile?.rank_points)),
    matchRecord: {
      scope: 'lifetime',
      wins,
      losses,
      draws,
      totalMatches,
      winRate:
        totalMatches === 0
          ? null
          : Number(((wins / totalMatches) * 100).toFixed(2)),
    },
    soloComparison: comparisonEligible
      ? {
          gapPercentagePoints: Number(
            (soloAccuracy!.value! - accuracyValue!).toFixed(2),
          ),
          solo: soloAccuracy,
          pvp: {
            value: accuracyValue,
            correctCount: correct,
            attemptCount: resolved.length,
            asOf: endsAt,
          },
        }
      : null,
  };
}

function dailyActivity(rows: any[], endsAt: string) {
  const dates = Array.from({ length: 30 }, (_, index) =>
    wibDate(new Date(Date.parse(endsAt) - (29 - index) * DAY_MS).toISOString()),
  );
  return dates.map((date) => {
    const entries = rows.filter((row) => wibDate(row.source_event_at) === date);
    const measured = entries
      .map((row) => nullableNumber(row.effective_response_time_ms))
      .filter((value): value is number => value !== null);
    const resolved = entries.filter(
      (row) => typeof row.is_correct === 'boolean',
    );
    return {
      date,
      questionsAnswered: entries.length,
      correctCount: resolved.filter((row) => row.is_correct).length,
      attemptCount: resolved.length,
      sessionCount: new Set(
        entries.map((row) => row.source_session_key).filter(Boolean),
      ).size,
      activeLearningMinutes:
        measured.length === 0
          ? null
          : Number(
              (
                measured.reduce((sum, value) => sum + value, 0) / 60_000
              ).toFixed(2),
            ),
    };
  });
}

function weeklyActivity(days: ReturnType<typeof dailyActivity>) {
  const buckets: Array<typeof days> = [];
  for (let index = 0; index < days.length; index += 7) {
    buckets.push(days.slice(index, index + 7));
  }
  return buckets.map((bucket) => ({
    startsOn: bucket[0].date,
    endsOn: bucket[bucket.length - 1].date,
    questionsAnswered: bucket.reduce(
      (sum, day) => sum + day.questionsAnswered,
      0,
    ),
    activeLearningMinutes: bucket.every(
      (day) => day.activeLearningMinutes === null,
    )
      ? null
      : Number(
          bucket
            .reduce((sum, day) => sum + (day.activeLearningMinutes ?? 0), 0)
            .toFixed(2),
        ),
    sessionCount: bucket.reduce((sum, day) => sum + day.sessionCount, 0),
  }));
}

function recentSessions(rows: any[], skillLabels: Map<string, string>) {
  const grouped = new Map<string, any[]>();
  for (const row of rows) {
    const key = String(row.source_session_key ?? '').trim();
    if (!key) continue;
    grouped.set(key, [...(grouped.get(key) ?? []), row]);
  }
  return Array.from(grouped.entries())
    .map(([sessionKey, entries]) => {
      const sorted = [...entries].sort((left, right) =>
        String(right.source_event_at).localeCompare(
          String(left.source_event_at),
        ),
      );
      const resolved = entries.filter(
        (row) => typeof row.is_correct === 'boolean',
      );
      const correctCount = resolved.filter((row) => row.is_correct).length;
      const skillIds = Array.from(
        new Set(
          entries
            .map((row) => String(row.skill_id ?? '').trim())
            .filter(Boolean),
        ),
      );
      return {
        sessionKey,
        lastActivityAt: sorted[0].source_event_at,
        completionState:
          sorted.find((row) => row.session_completion_state)
            ?.session_completion_state ?? 'in_progress',
        objective:
          sorted.find((row) => row.learning_objective)?.learning_objective ??
          null,
        mechanicMode:
          sorted.find((row) => row.effective_mechanic_mode)
            ?.effective_mechanic_mode ?? null,
        questionSelectionType:
          sorted.find((row) => row.question_selection_type)
            ?.question_selection_type ?? null,
        skillIds,
        skillLabels: skillIds.map(
          (skillId) => skillLabels.get(skillId) ?? skillId,
        ),
        correctCount,
        attemptCount: resolved.length,
        accuracy:
          resolved.length === 0
            ? null
            : Number(((correctCount / resolved.length) * 100).toFixed(2)),
      };
    })
    .sort((left, right) =>
      String(right.lastActivityAt).localeCompare(String(left.lastActivityAt)),
    )
    .slice(0, 5);
}

function assessmentSummary(rows: any[]) {
  const latest = rows[0] ?? null;
  if (!latest) {
    return {
      status: 'not_available',
      score: null,
      correctCount: null,
      attemptCount: null,
      occurredAt: null,
      blueprintVersion: null,
      confidence: 'low',
      asOf: null,
      baseline: null,
      latest: null,
      improvementPercentagePoints: null,
      categoryBreakdown: [],
      skillBreakdown: [],
    };
  }
  const comparable = rows.filter(
    (row) =>
      row.blueprint_version === latest.blueprint_version &&
      nullableNumber(row.score) !== null,
  );
  const baseline =
    comparable.length > 1 ? comparable[comparable.length - 1] : null;
  const improvement =
    baseline &&
    baseline.id !== latest.id &&
    nullableNumber(latest.score) !== null
      ? Number(
          (
            nullableNumber(latest.score)! - nullableNumber(baseline.score)!
          ).toFixed(2),
        )
      : null;
  return {
    status: latest.validation_status,
    score: nullableNumber(latest.score),
    correctCount: latest.correct_count,
    attemptCount: latest.attempt_count,
    occurredAt: latest.occurred_at,
    blueprintVersion: latest.blueprint_version,
    confidence: assessmentConfidence(latest.validation_status),
    asOf: latest.occurred_at,
    baseline: baseline ? assessmentPoint(baseline) : null,
    latest: assessmentPoint(latest),
    improvementPercentagePoints: improvement,
    categoryBreakdown: assessmentBreakdown(
      latest.category_breakdown,
      latest.validation_status,
      latest.occurred_at,
    ),
    skillBreakdown: assessmentBreakdown(
      latest.skill_breakdown,
      latest.validation_status,
      latest.occurred_at,
    ),
  };
}

function assessmentPoint(row: any) {
  return {
    score: nullableNumber(row.score),
    correctCount: row.correct_count,
    attemptCount: row.attempt_count,
    occurredAt: row.occurred_at,
    blueprintVersion: row.blueprint_version,
  };
}

function assessmentBreakdown(
  value: unknown,
  validationStatus: string,
  asOf: string,
) {
  if (!Array.isArray(value)) return [];
  return value.map((entry) => ({
    ...entry,
    correctCount: nullableNumber(entry?.correctCount),
    attemptCount: nullableNumber(entry?.attemptCount),
    confidence: assessmentConfidence(validationStatus),
    asOf,
  }));
}

function assessmentConfidence(status: string): EvidenceConfidence {
  if (status === 'validated') return 'high';
  if (status === 'baseline_recorded') return 'medium';
  return 'low';
}

function emptyDashboard(
  target: LearningTarget,
  startsAt: string,
  asOf: string,
) {
  return {
    asOf,
    calculationVersion: LEARNING_CALCULATION_VERSION,
    target,
    window: { type: 'rolling', days: 30, startsAt, endsAt: asOf },
    nextAction: null,
    summary: {
      curriculumCoverage: {
        value: null,
        coveredSkillCount: 0,
        requiredSkillCount: 0,
        confidence: 'low',
        asOf,
      },
      unseenIndependentAccuracy: metric(0, 0, 0, 'low', asOf),
      pace: {
        value: null,
        baselineType: null,
        attemptCount: 0,
        confidence: 'low',
        asOf,
      },
    },
    skillStates: [],
    trends: [],
    retention: [],
    assessment: assessmentSummary([]),
    activity: activitySummary([], startsAt, asOf),
    competition: competitionSummary([], startsAt, asOf),
  };
}

function requiredText(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new BadRequestException(`${field} must be a non-empty string.`);
  }
  if (value.length > maxLength) {
    throw new BadRequestException(
      `${field} must not exceed ${maxLength} characters.`,
    );
  }
  return value.trim();
}

function nullableNumber(value: unknown): number | null {
  return value === null || value === undefined ? null : Number(value);
}

function wibDate(value: string): string {
  return new Date(Date.parse(value) + 7 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

function wibWindowStart(asOf: Date, days: number): string {
  const wib = new Date(asOf.getTime() + 7 * 60 * 60 * 1000);
  return new Date(
    Date.UTC(
      wib.getUTCFullYear(),
      wib.getUTCMonth(),
      wib.getUTCDate() - (days - 1),
    ) -
      7 * 60 * 60 * 1000,
  ).toISOString();
}
