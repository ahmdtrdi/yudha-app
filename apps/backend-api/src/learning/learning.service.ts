import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { curriculumCoverage } from './learning.calculators';
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
    const startsAt = new Date(asOf.getTime() - 30 * DAY_MS).toISOString();
    const target = await this.repository.getUserTarget(userId);
    const taxonomy = await this.repository.getLatestTaxonomyVersion();
    if (!taxonomy) {
      return {
        data: emptyDashboard(target, startsAt, asOf.toISOString()),
      };
    }
    const [skills, prepared, recommendation, retention, assessment, activity] =
      await Promise.all([
        this.repository.listSkills(taxonomy.id, target),
        this.repository.listPreparedStates(userId, target, taxonomy.id),
        this.repository.getActiveRecommendation(userId, target),
        this.repository.listRetentionSchedules(userId, target, taxonomy.id),
        this.repository.getLatestAssessment(userId, target),
        this.repository.getActivity(
          userId,
          target,
          startsAt,
          asOf.toISOString(),
        ),
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
          unseenIndependentAccuracy: metric(
            totalCorrect,
            totalAttempts,
            totalUniqueQuestions,
            evidenceConfidence,
            asOf.toISOString(),
          ),
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
        })),
        assessment: assessment
          ? {
              status: assessment.validation_status,
              score: nullableNumber(assessment.score),
              correctCount: assessment.correct_count,
              attemptCount: assessment.attempt_count,
              occurredAt: assessment.occurred_at,
              blueprintVersion: assessment.blueprint_version,
            }
          : {
              status: 'not_available',
              score: null,
              correctCount: null,
              attemptCount: null,
              occurredAt: null,
              blueprintVersion: null,
            },
        activity: activitySummary(soloActivity, startsAt, asOf.toISOString()),
        competition: competitionSummary(
          competitionActivity,
          startsAt,
          asOf.toISOString(),
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

function activitySummary(rows: any[], startsAt: string, endsAt: string) {
  const measured = rows
    .map((row) => nullableNumber(row.effective_response_time_ms))
    .filter((value): value is number => value !== null);
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
  };
}

function competitionSummary(rows: any[], startsAt: string, endsAt: string) {
  const resolved = rows.filter((row) => typeof row.is_correct === 'boolean');
  const correct = resolved.filter((row) => row.is_correct).length;
  return {
    separateEvidenceContext: true,
    window: { days: 30, startsAt, endsAt },
    accuracy: {
      value:
        resolved.length === 0
          ? null
          : Number(((correct / resolved.length) * 100).toFixed(2)),
      correctCount: correct,
      attemptCount: resolved.length,
      confidence: null,
      asOf: endsAt,
    },
  };
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
    assessment: {
      status: 'not_available',
      score: null,
      correctCount: null,
      attemptCount: null,
      occurredAt: null,
      blueprintVersion: null,
    },
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
