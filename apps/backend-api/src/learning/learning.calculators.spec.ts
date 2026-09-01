import {
  calculateSkillState,
  classifyAttempt,
  confidence,
  curriculumCoverage,
  orderedState,
  rankRecommendation,
  trend,
} from './learning.calculators';
import type {
  ClassifiedAttempt,
  LearningAttemptEvidence,
  RecommendationCandidate,
  SkillStateProjection,
} from './learning.types';

const AS_OF = new Date('2026-09-01T00:00:00.000Z');

function attempt(
  index: number,
  overrides: Partial<LearningAttemptEvidence> = {},
): LearningAttemptEvidence {
  return {
    id: `attempt-${String(index).padStart(3, '0')}`,
    source: 'solo',
    userId: 'user-1',
    target: 'cpns',
    questionId: `question-${index}`,
    questionRevisionId: `revision-${index}`,
    taxonomyVersionId: 'taxonomy-1',
    skillId: 'cpns.tiu.numerik',
    difficulty: index % 2 === 0 ? 'easy' : 'medium',
    requestedMechanicMode: 'standard',
    effectiveMechanicMode: 'standard',
    selectedOptionIndex: 0,
    isCorrect: true,
    hintRequested: false,
    timedOut: false,
    firstAttempt: true,
    seenBefore: false,
    expectedTimeMs: 10_000,
    standardTimeLimitMs: 30_000,
    clientActiveResponseTimeMs: 10_000,
    serverElapsedTimeMs: 10_000,
    backgroundDurationMs: 0,
    effectiveResponseTimeMs: 10_000,
    timingInvalidityReason: null,
    sourceEventAt: new Date(AS_OF.getTime() - index * 60_000).toISOString(),
    ...overrides,
  };
}

function classified(
  index: number,
  overrides: Partial<LearningAttemptEvidence> = {},
): ClassifiedAttempt {
  const value = attempt(index, overrides);
  return { attempt: value, classification: classifyAttempt(value) };
}

function state(
  overrides: Partial<SkillStateProjection> = {},
): SkillStateProjection {
  return {
    status: 'secure',
    activityCorrectCount: 15,
    activityAttemptCount: 15,
    activityAccuracy: 100,
    independentCorrectCount: 15,
    independentAttemptCount: 15,
    independentAccuracy: 100,
    unseenCorrectCount: 15,
    unseenAttemptCount: 15,
    uniqueQuestionCount: 15,
    unseenIndependentAccuracy: 100,
    smoothedAccuracy: 89.47,
    assistedCorrectCount: 0,
    assistedAttemptCount: 0,
    assistedAccuracy: null,
    hintRate: 0,
    independenceGap: null,
    evidenceConfidence: 'high',
    difficultyLevelCount: 2,
    medianResponseTimeMs: 10_000,
    paceRatio: 1,
    paceBaselineType: 'calibrated',
    paceAttemptCount: 15,
    timeoutRate: 0,
    trendPercentagePoints: null,
    coverageSufficient: true,
    recommendedMechanic: 'standard',
    latestEligibleAt: '2026-08-31T00:00:00.000Z',
    lastPracticedAt: '2026-08-31T00:00:00.000Z',
    latestStrongEvidenceAt: '2026-08-31T00:00:00.000Z',
    ...overrides,
  };
}

function candidate(
  skillId: string,
  overrides: Partial<RecommendationCandidate> = {},
): RecommendationCandidate {
  return {
    taxonomyVersionId: 'taxonomy-1',
    skillId,
    skillLabel: skillId,
    category: 'TIU',
    subcategory: 'Numerik',
    curriculumWeight: 1,
    isRequired: true,
    inventoryCount: 5,
    state: state(),
    assessmentAccuracy: null,
    attemptsLast24Hours: 0,
    reviewDue: false,
    retentionAccuracy: null,
    ...overrides,
  };
}

describe('learning-v1 evidence classification', () => {
  it('keeps a server-hinted attempt in assisted evidence only', () => {
    const result = classifyAttempt(attempt(1, { hintRequested: true }));

    expect(result.validForActivityAccuracy).toBe(true);
    expect(result.validForAssistedAccuracy).toBe(true);
    expect(result.validForIndependentAccuracy).toBe(false);
    expect(result.validForUnseenIndependentAccuracy).toBe(false);
    expect(result.validForFluencyBaseline).toBe(false);
  });

  it('does not invent proficiency eligibility when revision is unknown', () => {
    const result = classifyAttempt(
      attempt(1, {
        source: 'pvp',
        questionRevisionId: null,
        hintRequested: null,
        firstAttempt: null,
        seenBefore: null,
      }),
    );

    expect(result.validForActivityAccuracy).toBe(false);
    expect(result.validForIndependentAccuracy).toBe(false);
    expect(result.exclusionReasons).toContain('revision_unknown');
    expect(result.exclusionReasons).toContain('pace_source_ineligible');
  });

  it('accepts the Focus timing tolerance boundary and rejects above it', () => {
    const boundary = classifyAttempt(
      attempt(1, {
        effectiveMechanicMode: 'focus',
        serverElapsedTimeMs: 10_000,
        clientActiveResponseTimeMs: 12_000,
      }),
    );
    const over = classifyAttempt(
      attempt(2, {
        effectiveMechanicMode: 'focus',
        serverElapsedTimeMs: 10_000,
        clientActiveResponseTimeMs: 12_001,
      }),
    );

    expect(boundary.validForPaceAnalytics).toBe(true);
    expect(boundary.effectiveResponseTimeMs).toBe(12_000);
    expect(over.validForPaceAnalytics).toBe(false);
    expect(over.effectiveResponseTimeMs).toBeNull();
  });

  it('caps timed pace at the authoritative limit and excludes timeouts from fluency', () => {
    const result = classifyAttempt(
      attempt(1, {
        timedOut: true,
        selectedOptionIndex: null,
        serverElapsedTimeMs: 35_000,
        standardTimeLimitMs: 30_000,
      }),
    );

    expect(result.validForPaceAnalytics).toBe(true);
    expect(result.effectiveResponseTimeMs).toBe(30_000);
    expect(result.validForFluencyBaseline).toBe(false);
  });
});

describe('learning-v1 skill projection', () => {
  it('returns null rather than zero for empty evidence', () => {
    const result = calculateSkillState({ attempts: [], asOf: AS_OF });

    expect(result.activityAccuracy).toBeNull();
    expect(result.unseenIndependentAccuracy).toBeNull();
    expect(result.smoothedAccuracy).toBeNull();
    expect(result.hintRate).toBeNull();
    expect(result.paceRatio).toBeNull();
    expect(result.timeoutRate).toBeNull();
    expect(result.trendPercentagePoints).toBeNull();
    expect(result.status).toBe('collecting_data');
  });

  it('matches the normative five-of-nine raw and smoothed boundary', () => {
    const attempts = Array.from({ length: 9 }, (_, index) =>
      classified(index, { isCorrect: index < 5 }),
    );

    const result = calculateSkillState({ attempts, asOf: AS_OF });

    expect(result.unseenCorrectCount).toBe(5);
    expect(result.unseenAttemptCount).toBe(9);
    expect(result.unseenIndependentAccuracy).toBe(55.56);
    expect(result.smoothedAccuracy).toBe(53.85);
    expect(result.status).toBe('needs_repair');
  });

  it('uses only the latest 20 eligible unseen-independent attempts', () => {
    const attempts = Array.from({ length: 25 }, (_, index) =>
      classified(index, { isCorrect: index < 20 }),
    );

    const result = calculateSkillState({ attempts, asOf: AS_OF });

    expect(result.unseenAttemptCount).toBe(20);
    expect(result.unseenCorrectCount).toBe(20);
    expect(result.unseenIndependentAccuracy).toBe(100);
  });

  it('calculates latest-ten versus previous-ten trend in percentage points', () => {
    const attempts = Array.from({ length: 20 }, (_, index) =>
      classified(index, {
        isCorrect: index < 8 || (index >= 10 && index < 14),
      }),
    );

    const result = calculateSkillState({ attempts, asOf: AS_OF });

    expect(result.trendPercentagePoints).toBe(40);
  });
});

describe('learning-v1 confidence and ordered state', () => {
  it('evaluates High before Medium and falls back honestly', () => {
    expect(
      confidence({
        attemptCount: 15,
        uniqueQuestionCount: 8,
        difficultyLevelCount: 2,
        latestEligibleAt: '2026-08-18T00:00:00.000Z',
        asOf: AS_OF,
      }),
    ).toBe('high');
    expect(
      confidence({
        attemptCount: 15,
        uniqueQuestionCount: 7,
        difficultyLevelCount: 2,
        latestEligibleAt: '2026-08-18T00:00:00.000Z',
        asOf: AS_OF,
      }),
    ).toBe('medium');
    expect(
      confidence({
        attemptCount: 15,
        uniqueQuestionCount: 8,
        difficultyLevelCount: 2,
        latestEligibleAt: '2026-08-17T23:59:59.999Z',
        asOf: AS_OF,
      }),
    ).toBe('medium');
    expect(
      confidence({
        attemptCount: 15,
        uniqueQuestionCount: 8,
        difficultyLevelCount: 2,
        latestEligibleAt: '2026-08-01T23:59:59.999Z',
        asOf: AS_OF,
      }),
    ).toBe('low');
  });

  it.each([
    [{ unseenAttemptCount: 4, uniqueQuestionCount: 4 }, 'collecting_data'],
    [{ unseenAttemptCount: 5, uniqueQuestionCount: 2 }, 'collecting_data'],
    [{ smoothedAccuracy: 69.99 }, 'needs_repair'],
    [{ smoothedAccuracy: 70 }, 'developing'],
    [{ smoothedAccuracy: 84.99 }, 'developing'],
    [
      {
        smoothedAccuracy: 85,
        retention: {
          strongEvidenceAt: '2026-08-25T00:00:00.000Z',
          reviewDueAt: '2026-09-01T00:00:00.000Z',
          reviewDue: true,
          retentionCorrectCount: 0,
          retentionAttemptCount: 0,
          retentionAccuracy: null,
        },
        paceRatio: 1.3,
        paceAttemptCount: 5,
      },
      'needs_review',
    ],
    [
      { smoothedAccuracy: 85, paceRatio: 1.2001, paceAttemptCount: 5 },
      'needs_fluency',
    ],
    [
      {
        smoothedAccuracy: 85,
        paceRatio: 1.2,
        paceAttemptCount: 5,
        evidenceConfidence: 'medium' as const,
      },
      'secure',
    ],
    [
      {
        smoothedAccuracy: 85,
        paceRatio: 1,
        paceAttemptCount: 5,
        evidenceConfidence: 'low' as const,
      },
      'collecting_data',
    ],
  ])('orders boundary input %o as %s', (overrides, expected) => {
    expect(
      orderedState({
        unseenAttemptCount: 15,
        uniqueQuestionCount: 8,
        smoothedAccuracy: 85,
        evidenceConfidence: 'high',
        paceRatio: 1,
        paceAttemptCount: 5,
        latestStrongEvidenceAt: '2026-08-31T00:00:00.000Z',
        retention: null,
        asOf: AS_OF,
        ...overrides,
      }),
    ).toBe(expected);
  });
});

describe('learning-v1 coverage and recommendation ranking', () => {
  it('returns null coverage for no required enabled skills', () => {
    expect(curriculumCoverage([])).toEqual({
      coveredSkillCount: 0,
      requiredSkillCount: 0,
      coveragePercentage: null,
    });
    expect(
      curriculumCoverage([
        { isRequired: true, enabled: true, uniqueQuestionCount: 3 },
        { isRequired: true, enabled: true, uniqueQuestionCount: 2 },
        { isRequired: false, enabled: true, uniqueQuestionCount: 3 },
      ]),
    ).toEqual({
      coveredSkillCount: 1,
      requiredSkillCount: 2,
      coveragePercentage: 50,
    });
  });

  it('does not emit a compatibility action without five active questions', () => {
    expect(
      rankRecommendation([candidate('cpns.twk', { inventoryCount: 4 })], AS_OF),
    ).toBeNull();
  });

  it('enforces objective order before comparing skill priorities', () => {
    const result = rankRecommendation(
      [
        candidate('cpns.review', {
          reviewDue: true,
          state: state({ status: 'needs_review' }),
        }),
        candidate('cpns.repair', {
          state: state({ status: 'needs_repair', smoothedAccuracy: 69.99 }),
        }),
      ],
      AS_OF,
    );

    expect(result?.objective).toBe('repair_accuracy');
    expect(result?.candidate.skillId).toBe('cpns.repair');
    expect(result?.mechanicMode).toBe('focus');
  });

  it('uses the supplied as-of time and stable skill ID for deterministic ties', () => {
    const first = candidate('cpns.a', {
      reviewDue: true,
      state: state({
        status: 'needs_review',
        latestStrongEvidenceAt: '2026-08-25T00:00:00.000Z',
      }),
    });
    const second = candidate('cpns.b', {
      reviewDue: true,
      state: state({
        status: 'needs_review',
        latestStrongEvidenceAt: '2026-08-25T00:00:00.000Z',
      }),
    });

    const result = rankRecommendation([second, first], AS_OF);

    expect(result?.objective).toBe('spaced_review');
    expect(result?.candidate.skillId).toBe('cpns.a');
    expect(result?.priority).toBe(0.75);
  });

  it('keeps trend null until both ten-attempt blocks exist', () => {
    expect(
      trend(Array.from({ length: 19 }, (_, index) => classified(index))),
    ).toBeNull();
  });
});
