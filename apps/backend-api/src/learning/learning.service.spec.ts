import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { LearningService } from './learning.service';

describe('LearningService', () => {
  const previousFlag = process.env.LEARNING_V2_ENABLED;

  afterEach(() => {
    jest.useRealTimers();
    if (previousFlag === undefined) delete process.env.LEARNING_V2_ENABLED;
    else process.env.LEARNING_V2_ENABLED = previousFlag;
  });

  it('keeps rollout disabled unless explicitly enabled', async () => {
    delete process.env.LEARNING_V2_ENABLED;
    const service = new LearningService({} as any);

    await expect(service.getDashboard('user-1')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('returns honest null metrics when taxonomy is not synchronized', async () => {
    process.env.LEARNING_V2_ENABLED = 'true';
    const repository = {
      getUserTarget: jest.fn().mockResolvedValue('cpns'),
      getLatestTaxonomyVersion: jest.fn().mockResolvedValue(null),
    };
    const service = new LearningService(repository as any);

    const result = await service.getDashboard('user-1');

    expect(result.data.summary.unseenIndependentAccuracy).toMatchObject({
      value: null,
      correctCount: 0,
      attemptCount: 0,
      uniqueQuestionCount: 0,
      confidence: 'low',
    });
    expect(result.data.summary.pace.value).toBeNull();
    expect(result.data.assessment.status).toBe('not_available');
    expect(result.data.competition.accuracy.value).toBeNull();
  });

  it('returns additive coaching context without mixing evidence lanes', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-09-02T08:30:00.000Z'));
    process.env.LEARNING_V2_ENABLED = 'true';
    const repository = {
      getUserTarget: jest.fn().mockResolvedValue('cpns'),
      getLatestTaxonomyVersion: jest.fn().mockResolvedValue({ id: 'tax-1' }),
      listSkills: jest.fn().mockResolvedValue([
        {
          skill_id: 'cpns.tiu.numerik',
          label: 'TIU Numerik',
          category: 'tiu',
          subcategory: 'numerik',
          is_required: true,
          enabled: true,
        },
      ]),
      listPreparedStates: jest.fn().mockResolvedValue([]),
      getActiveRecommendation: jest.fn().mockResolvedValue(null),
      listRetentionSchedules: jest.fn().mockResolvedValue([
        {
          skill_id: 'cpns.tiu.numerik',
          strong_evidence_at: '2026-08-20T02:00:00.000Z',
          review_due_at: '2026-08-27T02:00:00.000Z',
          status: 'due',
          retention_correct_count: 3,
          retention_attempt_count: 4,
          retention_accuracy: 75,
        },
      ]),
      listAssessmentEvidence: jest.fn().mockResolvedValue([
        {
          id: 'assessment-latest',
          blueprint_version: 'cpns-1',
          validation_status: 'validated',
          score: 84,
          correct_count: 84,
          attempt_count: 100,
          category_breakdown: [{ category: 'tiu', score: 86 }],
          skill_breakdown: [],
          occurred_at: '2026-09-01T02:00:00.000Z',
        },
        {
          id: 'assessment-baseline',
          blueprint_version: 'cpns-1',
          validation_status: 'baseline_recorded',
          score: 76,
          correct_count: 76,
          attempt_count: 100,
          category_breakdown: [],
          skill_breakdown: [],
          occurred_at: '2026-08-01T02:00:00.000Z',
        },
      ]),
      getActivity: jest.fn().mockResolvedValue([
        {
          id: 'solo-1',
          source: 'solo',
          source_session_key: 'session-1',
          source_event_at: new Date().toISOString(),
          effective_response_time_ms: 30_000,
          is_correct: true,
          question_revision_id: 'question-1',
          skill_id: 'cpns.tiu.numerik',
          effective_mechanic_mode: 'focus',
          session_completion_state: 'compatibility_completed',
        },
        ...Array.from({ length: 5 }, (_, index) => ({
          id: `pvp-${index}`,
          source: 'pvp',
          source_session_key: 'match-1',
          source_event_at: new Date().toISOString(),
          effective_response_time_ms: 20_000,
          difficulty: index % 2 === 0 ? 'medium' : 'hard',
          is_correct: index < 4,
          question_revision_id: `pvp-question-${index}`,
        })),
      ]),
      getLearningProfile: jest.fn().mockResolvedValue({
        rank_points: 850,
        wins: 12,
        losses: 7,
        draws: 1,
        current_streak: 5,
        best_streak: 11,
        last_streak_date: '2026-09-02',
      }),
    };
    const service = new LearningService(repository as any);

    const result = await service.getDashboard('user-1');

    expect(result.data.retention[0].label).toBe('TIU Numerik');
    expect(result.data.activity.dailyHistory).toHaveLength(30);
    expect(result.data.activity.dailyHistory[0].date).toBe('2026-08-04');
    expect(result.data.activity.dailyHistory[29].date).toBe('2026-09-02');
    expect(repository.getActivity).toHaveBeenCalledWith(
      'user-1',
      'cpns',
      '2026-08-03T17:00:00.000Z',
      '2026-09-02T08:30:00.000Z',
    );
    expect(result.data.activity.recentSessions[0]).toMatchObject({
      sessionKey: 'session-1',
      skillLabels: ['TIU Numerik'],
      correctCount: 1,
    });
    expect(result.data.activity.streak.current).toBe(5);
    expect(result.data.assessment.improvementPercentagePoints).toBe(8);
    expect(result.data.assessment.baseline.score).toBe(76);
    expect(result.data.assessment.latest.score).toBe(84);
    expect(result.data.competition).toMatchObject({
      rankPoints: 850,
      tier: 'elite',
      accuracy: { confidence: 'medium', uniqueQuestionCount: 5 },
      matchRecord: { wins: 12, losses: 7, draws: 1, totalMatches: 20 },
      soloComparison: null,
    });
  });

  it('requires a supported reason only for dismissal events', async () => {
    process.env.LEARNING_V2_ENABLED = 'true';
    const service = new LearningService({} as any);

    await expect(
      service.recordRecommendationEvent('user-1', 'recommendation-1', {
        idempotencyKey: 'event-1',
        eventType: 'dismissed',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.recordRecommendationEvent('user-1', 'recommendation-1', {
        idempotencyKey: 'event-2',
        eventType: 'accepted',
        dismissalReason: 'other',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
