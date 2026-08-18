import { BadRequestException } from '@nestjs/common';
import { PracticeRepository } from './practice.repository';
import { PracticeService } from './practice.service';

describe('PracticeService Gate 1 contract', () => {
  let repository: jest.Mocked<PracticeRepository>;
  let service: PracticeService;

  beforeEach(() => {
    repository = {
      createTransactionalSession: jest.fn(),
      submitTransactionalAnswer: jest.fn(),
      finishTransactionalSession: jest.fn(),
      getUserTarget: jest.fn(),
      listOwnedSessions: jest.fn(),
      countOwnedSessions: jest.fn(),
      countAnswersForSessions: jest.fn(),
    } as unknown as jest.Mocked<PracticeRepository>;
    service = new PracticeService(repository);
  });

  it('creates an unfiltered five-question session without leaking answers', async () => {
    repository.createTransactionalSession.mockResolvedValue({
      sessionId: 'session-1',
      questions: Array.from({ length: 5 }, (_, index) => ({
        sessionQuestionId: `sq-${index}`,
        prompt: `Question ${index}`,
        options: ['A', 'B', 'C', 'D'],
      })),
    });

    const result = await service.createSession('user-1', {});

    expect(repository.createTransactionalSession).toHaveBeenCalledWith(
      'user-1',
      null,
      null,
    );
    expect(result.data.questions).toHaveLength(5);
    expect(result.data.questions[0]).not.toHaveProperty('correctOptionIndex');
    expect(result.data.questions[0]).not.toHaveProperty('explanation');
  });

  it('requires category when subcategory is supplied', async () => {
    await expect(
      service.createSession('user-1', { subcategory: 'verbal' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('submits an answer through the idempotent transaction', async () => {
    repository.submitTransactionalAnswer.mockResolvedValue({
      sessionId: 'session-1',
      replayed: false,
      isCorrect: true,
    });

    const result = await service.submitAnswer('user-1', 'session-1', {
      idempotencyKey: 'answer-key-1',
      sessionQuestionId: 'sq-1',
      selectedOptionIndex: 2,
      usedHint: false,
      responseTimeMs: 1200,
    });

    expect(repository.submitTransactionalAnswer).toHaveBeenCalledWith({
      userId: 'user-1',
      sessionId: 'session-1',
      idempotencyKey: 'answer-key-1',
      sessionQuestionId: 'sq-1',
      selectedOptionIndex: 2,
      usedHint: false,
      responseTimeMs: 1200,
    });
    expect(result.data.replayed).toBe(false);
  });

  it('finishes only through the idempotent completion transaction', async () => {
    repository.finishTransactionalSession.mockResolvedValue({
      sessionId: 'session-1',
      correctCount: 4,
    });

    await service.finishSession('user-1', 'session-1', {
      idempotencyKey: 'finish-key-1',
    });

    expect(repository.finishTransactionalSession).toHaveBeenCalledWith(
      'user-1',
      'session-1',
      'finish-key-1',
    );
  });
});
