import {
  EVIDENCE_CLASSIFICATION_VERSION,
  LEARNING_COMPATIBILITY_INVENTORY_MINIMUM,
  LEARNING_STALE_STRONG_EVIDENCE_DAYS,
  LEARNING_STATE_ATTEMPT_LIMIT,
  LEARNING_TREND_BLOCK_SIZE,
} from './learning.constants';
import type {
  ClassificationContext,
  ClassifiedAttempt,
  EvidenceClassification,
  EvidenceConfidence,
  LearningAttemptEvidence,
  RankedRecommendation,
  RecommendationCandidate,
  SkillProjectionInput,
  SkillStateProjection,
  SoloSkillStatus,
} from './learning.types';

const DAY_MS = 24 * 60 * 60 * 1000;

export function classifyAttempt(
  attempt: LearningAttemptEvidence,
  context: ClassificationContext = {},
): EvidenceClassification {
  const exclusionReasons = new Set<string>();
  const ownershipValid = context.ownershipValid ?? true;
  const sessionLegitimate = context.sessionLegitimate ?? true;
  const sourceDuplicated = context.sourceDuplicated ?? false;
  const revisionInvalidated = context.revisionInvalidated ?? false;
  const resolutionRecorded =
    typeof attempt.isCorrect === 'boolean' &&
    (attempt.selectedOptionIndex !== null || attempt.timedOut === true);

  if (!resolutionRecorded) exclusionReasons.add('resolution_not_recorded');
  if (!ownershipValid) exclusionReasons.add('ownership_invalid');
  if (!sessionLegitimate) exclusionReasons.add('session_illegitimate');
  if (!attempt.questionId) exclusionReasons.add('question_unknown');
  if (!attempt.questionRevisionId) exclusionReasons.add('revision_unknown');
  if (sourceDuplicated) exclusionReasons.add('duplicate_source_item');
  if (revisionInvalidated) exclusionReasons.add('revision_invalidated');

  const validForActivityAccuracy =
    resolutionRecorded &&
    ownershipValid &&
    sessionLegitimate &&
    Boolean(attempt.questionId) &&
    Boolean(attempt.questionRevisionId) &&
    !sourceDuplicated &&
    !revisionInvalidated;
  const solo = attempt.source === 'solo';
  const validForIndependentAccuracy =
    validForActivityAccuracy &&
    solo &&
    attempt.firstAttempt === true &&
    attempt.hintRequested === false;
  const validForUnseenIndependentAccuracy =
    validForIndependentAccuracy && attempt.seenBefore === false;
  const validForAssistedAccuracy =
    validForActivityAccuracy && solo && attempt.hintRequested === true;

  const pace = classifyPace(attempt, validForActivityAccuracy);
  for (const reason of pace.exclusionReasons) exclusionReasons.add(reason);
  const validForFluencyBaseline =
    pace.valid &&
    validForUnseenIndependentAccuracy &&
    attempt.timedOut === false &&
    attempt.backgroundDurationMs === 0 &&
    !attempt.timingInvalidityReason &&
    Boolean(attempt.skillId) &&
    Boolean(attempt.difficulty);
  if (pace.valid && !validForFluencyBaseline) {
    exclusionReasons.add('not_fluency_comparable');
  }

  return {
    classificationVersion: EVIDENCE_CLASSIFICATION_VERSION,
    validForActivityAccuracy,
    validForIndependentAccuracy,
    validForUnseenIndependentAccuracy,
    validForAssistedAccuracy,
    validForPaceAnalytics: pace.valid,
    validForFluencyBaseline,
    validForRetention:
      validForUnseenIndependentAccuracy && (context.retentionEligible ?? false),
    effectiveResponseTimeMs: pace.effectiveResponseTimeMs,
    exclusionReasons: [...exclusionReasons].sort(),
  };
}

function classifyPace(
  attempt: LearningAttemptEvidence,
  validForActivityAccuracy: boolean,
): {
  valid: boolean;
  effectiveResponseTimeMs: number | null;
  exclusionReasons: string[];
} {
  if (!validForActivityAccuracy || attempt.source !== 'solo') {
    return {
      valid: false,
      effectiveResponseTimeMs: null,
      exclusionReasons: ['pace_source_ineligible'],
    };
  }
  if (attempt.timingInvalidityReason) {
    return {
      valid: false,
      effectiveResponseTimeMs: null,
      exclusionReasons: ['timing_invalid'],
    };
  }

  if (attempt.effectiveMechanicMode === 'focus') {
    if (
      attempt.clientActiveResponseTimeMs === null ||
      attempt.serverElapsedTimeMs === null ||
      attempt.backgroundDurationMs === null
    ) {
      return {
        valid: false,
        effectiveResponseTimeMs: null,
        exclusionReasons: ['focus_timing_incomplete'],
      };
    }
    const difference = Math.abs(
      attempt.clientActiveResponseTimeMs - attempt.serverElapsedTimeMs,
    );
    const tolerance = Math.max(2000, attempt.serverElapsedTimeMs * 0.15);
    const valid = attempt.backgroundDurationMs === 0 && difference <= tolerance;
    return {
      valid,
      effectiveResponseTimeMs: valid
        ? attempt.clientActiveResponseTimeMs
        : null,
      exclusionReasons: valid ? [] : ['focus_timing_inconsistent'],
    };
  }

  if (
    attempt.effectiveMechanicMode === 'standard' ||
    attempt.effectiveMechanicMode === 'speed'
  ) {
    if (
      attempt.serverElapsedTimeMs === null ||
      attempt.standardTimeLimitMs === null
    ) {
      return {
        valid: false,
        effectiveResponseTimeMs: null,
        exclusionReasons: ['timed_mode_timing_incomplete'],
      };
    }
    return {
      valid: true,
      effectiveResponseTimeMs: Math.min(
        attempt.serverElapsedTimeMs,
        attempt.standardTimeLimitMs,
      ),
      exclusionReasons: [],
    };
  }

  return {
    valid: false,
    effectiveResponseTimeMs: null,
    exclusionReasons: ['mechanic_unknown'],
  };
}

export function calculateSkillState(
  input: SkillProjectionInput,
): SkillStateProjection {
  const usable = input.attempts.filter(
    (entry) => !entry.invalidated && entry.attempt.source === 'solo',
  );
  const sorted = [...usable].sort(
    (left, right) =>
      Date.parse(right.attempt.sourceEventAt) -
        Date.parse(left.attempt.sourceEventAt) ||
      right.attempt.id.localeCompare(left.attempt.id),
  );
  const activity = takeEligible(
    sorted,
    (entry) => entry.classification.validForActivityAccuracy,
  );
  const independent = takeEligible(
    sorted,
    (entry) => entry.classification.validForIndependentAccuracy,
  );
  const unseen = takeEligible(
    sorted,
    (entry) => entry.classification.validForUnseenIndependentAccuracy,
  );
  const assisted = takeEligible(
    sorted,
    (entry) => entry.classification.validForAssistedAccuracy,
  );
  const pace = takeEligible(
    sorted,
    (entry) => entry.classification.validForPaceAnalytics,
  );
  const activityCounts = counts(activity);
  const independentCounts = counts(independent);
  const unseenCounts = counts(unseen);
  const assistedCounts = counts(assisted);
  const uniqueQuestionCount = new Set(
    unseen.map(
      (entry) => entry.attempt.questionRevisionId ?? entry.attempt.questionId,
    ),
  ).size;
  const difficultyLevelCount = new Set(
    unseen.map((entry) => entry.attempt.difficulty).filter(Boolean),
  ).size;
  const latestEligibleAt = unseen[0]?.attempt.sourceEventAt ?? null;
  const evidenceConfidence = confidence({
    attemptCount: unseenCounts.attemptCount,
    uniqueQuestionCount,
    difficultyLevelCount,
    latestEligibleAt,
    asOf: input.asOf,
  });
  const unseenIndependentAccuracy = percentage(
    unseenCounts.correctCount,
    unseenCounts.attemptCount,
  );
  const smoothedAccuracy =
    unseenCounts.attemptCount === 0
      ? null
      : round2(
          ((unseenCounts.correctCount + 2) / (unseenCounts.attemptCount + 4)) *
            100,
        );
  const assistedAccuracy = percentage(
    assistedCounts.correctCount,
    assistedCounts.attemptCount,
  );
  const independentAccuracy = percentage(
    independentCounts.correctCount,
    independentCounts.attemptCount,
  );
  const hintEligible = activity.filter(
    (entry) => typeof entry.attempt.hintRequested === 'boolean',
  );
  const hinted = hintEligible.filter(
    (entry) => entry.attempt.hintRequested === true,
  ).length;
  const paceTimes = pace
    .map((entry) => entry.classification.effectiveResponseTimeMs)
    .filter((value): value is number => value !== null);
  const calibratedRatios = pace
    .filter(
      (entry) =>
        entry.classification.effectiveResponseTimeMs !== null &&
        entry.attempt.expectedTimeMs !== null,
    )
    .map(
      (entry) =>
        entry.classification.effectiveResponseTimeMs! /
        entry.attempt.expectedTimeMs!,
    );
  const timedAttempts = activity.filter(
    (entry) =>
      entry.attempt.effectiveMechanicMode === 'standard' ||
      entry.attempt.effectiveMechanicMode === 'speed',
  );
  const timeoutCount = timedAttempts.filter(
    (entry) => entry.attempt.timedOut === true,
  ).length;
  const trendPercentagePoints = trend(unseen);
  const latestStrongEvidenceAt =
    smoothedAccuracy !== null &&
    smoothedAccuracy >= 85 &&
    evidenceConfidence !== 'low'
      ? latestEligibleAt
      : (input.retention?.strongEvidenceAt ?? null);
  const paceRatio =
    calibratedRatios.length === 0 ? null : round4(median(calibratedRatios));
  const paceAttemptCount = calibratedRatios.length;
  const status = orderedState({
    unseenAttemptCount: unseenCounts.attemptCount,
    uniqueQuestionCount,
    smoothedAccuracy,
    evidenceConfidence,
    paceRatio,
    paceAttemptCount,
    latestStrongEvidenceAt,
    retention: input.retention ?? null,
    asOf: input.asOf,
  });

  return {
    status,
    activityCorrectCount: activityCounts.correctCount,
    activityAttemptCount: activityCounts.attemptCount,
    activityAccuracy: percentage(
      activityCounts.correctCount,
      activityCounts.attemptCount,
    ),
    independentCorrectCount: independentCounts.correctCount,
    independentAttemptCount: independentCounts.attemptCount,
    independentAccuracy,
    unseenCorrectCount: unseenCounts.correctCount,
    unseenAttemptCount: unseenCounts.attemptCount,
    uniqueQuestionCount,
    unseenIndependentAccuracy,
    smoothedAccuracy,
    assistedCorrectCount: assistedCounts.correctCount,
    assistedAttemptCount: assistedCounts.attemptCount,
    assistedAccuracy,
    hintRate: percentage(hinted, hintEligible.length),
    independenceGap:
      assistedAccuracy === null || independentAccuracy === null
        ? null
        : round2(assistedAccuracy - independentAccuracy),
    evidenceConfidence,
    difficultyLevelCount,
    medianResponseTimeMs:
      paceTimes.length === 0 ? null : Math.round(median(paceTimes)),
    paceRatio,
    paceBaselineType: paceRatio === null ? null : 'calibrated',
    paceAttemptCount,
    timeoutRate: percentage(timeoutCount, timedAttempts.length),
    trendPercentagePoints,
    coverageSufficient: uniqueQuestionCount >= 3,
    recommendedMechanic:
      status === 'needs_repair'
        ? 'focus'
        : status === 'needs_fluency'
          ? 'speed'
          : 'standard',
    latestEligibleAt,
    lastPracticedAt: sorted[0]?.attempt.sourceEventAt ?? null,
    latestStrongEvidenceAt,
  };
}

function takeEligible(
  attempts: ClassifiedAttempt[],
  eligible: (attempt: ClassifiedAttempt) => boolean,
): ClassifiedAttempt[] {
  return attempts.filter(eligible).slice(0, LEARNING_STATE_ATTEMPT_LIMIT);
}

function counts(attempts: ClassifiedAttempt[]) {
  return {
    attemptCount: attempts.length,
    correctCount: attempts.filter((entry) => entry.attempt.isCorrect === true)
      .length,
  };
}

export function confidence(input: {
  attemptCount: number;
  uniqueQuestionCount: number;
  difficultyLevelCount: number;
  latestEligibleAt: string | null;
  asOf: Date;
}): EvidenceConfidence {
  const ageDays = input.latestEligibleAt
    ? (input.asOf.getTime() - Date.parse(input.latestEligibleAt)) / DAY_MS
    : Number.POSITIVE_INFINITY;
  if (
    input.attemptCount >= 15 &&
    input.uniqueQuestionCount >= 8 &&
    input.difficultyLevelCount >= 2 &&
    ageDays <= 14
  ) {
    return 'high';
  }
  if (
    input.attemptCount >= 5 &&
    input.uniqueQuestionCount >= 3 &&
    ageDays <= 30
  ) {
    return 'medium';
  }
  return 'low';
}

export function orderedState(input: {
  unseenAttemptCount: number;
  uniqueQuestionCount: number;
  smoothedAccuracy: number | null;
  evidenceConfidence: EvidenceConfidence;
  paceRatio: number | null;
  paceAttemptCount: number;
  latestStrongEvidenceAt: string | null;
  retention: SkillProjectionInput['retention'];
  asOf: Date;
}): SoloSkillStatus {
  if (input.unseenAttemptCount < 5 || input.uniqueQuestionCount < 3) {
    return 'collecting_data';
  }
  if (input.smoothedAccuracy === null || input.smoothedAccuracy < 70) {
    return 'needs_repair';
  }
  if (input.smoothedAccuracy < 85) return 'developing';

  const staleStrongEvidence =
    input.latestStrongEvidenceAt !== null &&
    input.asOf.getTime() - Date.parse(input.latestStrongEvidenceAt) >
      LEARNING_STALE_STRONG_EVIDENCE_DAYS * DAY_MS;
  if (
    input.retention?.reviewDue ||
    (input.retention?.retentionAccuracy != null &&
      input.retention.retentionAccuracy < 75) ||
    staleStrongEvidence
  ) {
    return 'needs_review';
  }
  if (
    input.paceRatio !== null &&
    input.paceAttemptCount >= 5 &&
    input.paceRatio > 1.2
  ) {
    return 'needs_fluency';
  }
  return input.evidenceConfidence === 'low' ? 'collecting_data' : 'secure';
}

export function trend(attempts: ClassifiedAttempt[]): number | null {
  if (attempts.length < LEARNING_TREND_BLOCK_SIZE * 2) return null;
  const latest = attempts.slice(0, LEARNING_TREND_BLOCK_SIZE);
  const previous = attempts.slice(
    LEARNING_TREND_BLOCK_SIZE,
    LEARNING_TREND_BLOCK_SIZE * 2,
  );
  return round2(
    percentage(counts(latest).correctCount, latest.length)! -
      percentage(counts(previous).correctCount, previous.length)!,
  );
}

export function curriculumCoverage(
  states: Array<{
    isRequired: boolean;
    enabled: boolean;
    uniqueQuestionCount: number;
  }>,
): {
  coveredSkillCount: number;
  requiredSkillCount: number;
  coveragePercentage: number | null;
} {
  const required = states.filter((state) => state.isRequired && state.enabled);
  const covered = required.filter((state) => state.uniqueQuestionCount >= 3);
  return {
    coveredSkillCount: covered.length,
    requiredSkillCount: required.length,
    coveragePercentage: percentage(covered.length, required.length),
  };
}

export function rankRecommendation(
  candidates: RecommendationCandidate[],
  asOf: Date = new Date(),
): RankedRecommendation | null {
  const runnable = candidates.filter(
    (candidate) =>
      candidate.inventoryCount >= LEARNING_COMPATIBILITY_INVENTORY_MINIMUM,
  );
  if (runnable.length === 0) return null;
  const objective = selectObjective(runnable);
  const eligible = runnable.filter((candidate) =>
    candidateMatchesObjective(candidate, objective),
  );
  const selected = [...eligible].sort((left, right) =>
    compareCandidates(objective, left, right, runnable, asOf),
  )[0];
  if (!selected) return null;
  const mechanicMode =
    objective === 'repair_accuracy'
      ? 'focus'
      : objective === 'build_fluency'
        ? 'speed'
        : 'standard';
  const questionSelectionType =
    objective === 'maintain_coverage' ? 'balanced' : 'recommended';
  return {
    objective,
    mechanicMode,
    questionSelectionType,
    candidate: selected,
    priority: numericPriority(objective, selected, runnable, asOf),
    availability: {
      runnable: true,
      reason: null,
      executionAdapter: 'practice_fixed_five',
    },
    reasonEvidence: recommendationEvidence(selected),
  };
}

function selectObjective(
  candidates: RecommendationCandidate[],
): RankedRecommendation['objective'] {
  if (
    candidates.some((candidate) => candidate.state.status === 'needs_repair')
  ) {
    return 'repair_accuracy';
  }
  if (
    candidates.some(
      (candidate) =>
        candidate.state.status === 'needs_review' || candidate.reviewDue,
    )
  ) {
    return 'spaced_review';
  }
  if (
    candidates.some(
      (candidate) =>
        candidate.isRequired &&
        (candidate.state.status === 'collecting_data' ||
          !candidate.state.coverageSufficient),
    )
  ) {
    return 'collect_evidence';
  }
  if (
    candidates.some((candidate) => candidate.state.status === 'needs_fluency')
  ) {
    return 'build_fluency';
  }
  return 'maintain_coverage';
}

function candidateMatchesObjective(
  candidate: RecommendationCandidate,
  objective: RankedRecommendation['objective'],
): boolean {
  if (objective === 'repair_accuracy') {
    return candidate.state.status === 'needs_repair';
  }
  if (objective === 'spaced_review') {
    return candidate.state.status === 'needs_review' || candidate.reviewDue;
  }
  if (objective === 'collect_evidence') {
    return (
      candidate.isRequired &&
      (candidate.state.status === 'collecting_data' ||
        !candidate.state.coverageSufficient)
    );
  }
  if (objective === 'build_fluency') {
    return candidate.state.status === 'needs_fluency';
  }
  return true;
}

function compareCandidates(
  objective: RankedRecommendation['objective'],
  left: RecommendationCandidate,
  right: RecommendationCandidate,
  all: RecommendationCandidate[],
  asOf: Date,
): number {
  if (objective === 'collect_evidence') {
    return (
      left.state.unseenAttemptCount - right.state.unseenAttemptCount ||
      left.state.uniqueQuestionCount - right.state.uniqueQuestionCount ||
      right.curriculumWeight - left.curriculumWeight ||
      left.attemptsLast24Hours - right.attemptsLast24Hours ||
      compareOldest(left.state.lastPracticedAt, right.state.lastPracticedAt) ||
      left.skillId.localeCompare(right.skillId)
    );
  }
  if (objective === 'maintain_coverage') {
    return (
      Number(right.reviewDue) - Number(left.reviewDue) ||
      compareOldest(left.state.lastPracticedAt, right.state.lastPracticedAt) ||
      right.curriculumWeight - left.curriculumWeight ||
      left.attemptsLast24Hours - right.attemptsLast24Hours ||
      left.skillId.localeCompare(right.skillId)
    );
  }
  const leftPriority = numericPriority(objective, left, all, asOf) ?? 0;
  const rightPriority = numericPriority(objective, right, all, asOf) ?? 0;
  return (
    rightPriority - leftPriority || left.skillId.localeCompare(right.skillId)
  );
}

function numericPriority(
  objective: RankedRecommendation['objective'],
  candidate: RecommendationCandidate,
  all: RecommendationCandidate[],
  asOf: Date,
): number | null {
  const maxWeight = Math.max(...all.map((entry) => entry.curriculumWeight), 1);
  const curriculumImportance = clamp(candidate.curriculumWeight / maxWeight);
  const repetitionPenalty = clamp(candidate.attemptsLast24Hours / 5);
  if (objective === 'repair_accuracy') {
    const positives = [
      {
        weight: 0.4,
        value: clamp((85 - (candidate.state.smoothedAccuracy ?? 50)) / 85),
      },
      ...(candidate.assessmentAccuracy === null
        ? []
        : [
            {
              weight: 0.25,
              value: clamp(1 - candidate.assessmentAccuracy / 100),
            },
          ]),
      ...(candidate.state.hintRate === null
        ? []
        : [
            {
              weight: 0.15,
              value: clamp(candidate.state.hintRate / 100),
            },
          ]),
      { weight: 0.2, value: curriculumImportance },
    ];
    const weightSum = positives.reduce((sum, entry) => sum + entry.weight, 0);
    const positiveScore = positives.reduce(
      (sum, entry) => sum + (entry.weight / weightSum) * entry.value,
      0,
    );
    return round4(positiveScore - 0.2 * repetitionPenalty);
  }
  if (objective === 'spaced_review') {
    const retentionRisk =
      candidate.retentionAccuracy === null
        ? candidate.state.latestStrongEvidenceAt === null
          ? 1
          : clamp(
              (asOf.getTime() -
                Date.parse(candidate.state.latestStrongEvidenceAt)) /
                DAY_MS /
                7,
            )
        : clamp(1 - candidate.retentionAccuracy / 100);
    const uncertainty = clamp(1 - candidate.state.unseenAttemptCount / 15);
    return round4(
      0.5 * retentionRisk +
        0.25 * curriculumImportance +
        0.15 * uncertainty -
        0.2 * repetitionPenalty,
    );
  }
  if (objective === 'build_fluency') {
    const paceGap = clamp((candidate.state.paceRatio ?? 1) - 1);
    const timeoutRate = clamp((candidate.state.timeoutRate ?? 0) / 100);
    return round4(
      0.6 * paceGap +
        0.25 * curriculumImportance +
        0.15 * timeoutRate -
        0.2 * repetitionPenalty,
    );
  }
  return null;
}

function recommendationEvidence(
  candidate: RecommendationCandidate,
): Array<Record<string, unknown>> {
  return [
    {
      metric: 'unseenIndependentAccuracy',
      value: candidate.state.unseenIndependentAccuracy,
      correctCount: candidate.state.unseenCorrectCount,
      attemptCount: candidate.state.unseenAttemptCount,
      uniqueQuestionCount: candidate.state.uniqueQuestionCount,
      confidence: candidate.state.evidenceConfidence,
    },
  ];
}

function compareOldest(left: string | null, right: string | null): number {
  if (left === null && right === null) return 0;
  if (left === null) return -1;
  if (right === null) return 1;
  return Date.parse(left) - Date.parse(right);
}

function percentage(numerator: number, denominator: number): number | null {
  return denominator === 0 ? null : round2((numerator / denominator) * 100);
}

function median(values: number[]): number {
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
}

function clamp(value: number): number {
  return Math.min(1, Math.max(0, value));
}

function round2(value: number): number {
  return Number(value.toFixed(2));
}

function round4(value: number): number {
  return Number(value.toFixed(4));
}
