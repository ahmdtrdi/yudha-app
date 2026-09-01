import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { LearningService } from './learning.service';

describe('LearningService', () => {
  const previousFlag = process.env.LEARNING_V2_ENABLED;

  afterEach(() => {
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
