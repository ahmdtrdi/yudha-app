import { BadRequestException } from '@nestjs/common';
import { PracticeRepository } from './practice.repository';
import { PracticeService } from './practice.service';

describe('PracticeService Gate 1 contract', () => {
  let repository: jest.Mocked<PracticeRepository>;
  let service: PracticeService;
  let learningProjections: { rebuildAndDrainUser: jest.Mock };
  const previousFlag = process.env.LEARNING_V2_ENABLED;

  beforeEach(() => {
    repository = {
      createTransactionalSession: jest.fn(),
      submitTransactionalAnswer: jest.fn(),
      finishTransactionalSession: jest.fn(),
      getOwnedSession: jest.fn(),
      getUserTarget: jest.fn(),
      listOwnedSessions: jest.fn(),
      countOwnedSessions: jest.fn(),
      countAnswersForSessions: jest.fn(),
      createLearningV2Session: jest.fn(),
      requestLearningV2Hint: jest.fn(),
      submitLearningV2Answer: jest.fn(),
      finishLearningV2Session: jest.fn(),
    } as unknown as jest.Mocked<PracticeRepository>;
    learningProjections = { rebuildAndDrainUser: jest.fn() };
    service = new PracticeService(repository, learningProjections as any);
  });

  afterEach(() => {
    if (previousFlag === undefined) delete process.env.LEARNING_V2_ENABLED;
    else process.env.LEARNING_V2_ENABLED = previousFlag;
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
    repository.getOwnedSession.mockResolvedValue({
      id: 'session-1',
      target: 'cpns',
      evidence_capture_version: 'legacy-practice-v1',
    } as any);
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
    repository.getOwnedSession.mockResolvedValue({
      id: 'session-1',
      target: 'cpns',
      evidence_capture_version: 'legacy-practice-v1',
    } as any);
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

  it('attaches a recommendation and serves hints through V2 authority', async () => {
    process.env.LEARNING_V2_ENABLED = 'true';
    repository.createLearningV2Session.mockResolvedValue({
      sessionId: 'session-v2',
      questions: [],
    });
    repository.requestLearningV2Hint.mockResolvedValue({
      sessionId: 'session-v2',
      sessionQuestionId: 'sq-1',
      hint: 'Petunjuk server',
      hintRequestedAt: '2026-09-01T00:00:00.000Z',
    });

    await service.createSession('user-1', {
      category: 'tiu',
      subcategory: 'numerik',
      recommendationId: 'recommendation-1',
    });
    const hint = await service.requestHint('user-1', 'session-v2', 'sq-1', {
      idempotencyKey: 'hint-1',
    });

    expect(repository.createLearningV2Session).toHaveBeenCalledWith(
      'user-1',
      'tiu',
      'numerik',
      'recommendation-1',
    );
    expect(repository.requestLearningV2Hint).toHaveBeenCalledWith({
      userId: 'user-1',
      sessionId: 'session-v2',
      sessionQuestionId: 'sq-1',
      idempotencyKey: 'hint-1',
    });
    expect(hint.data.hint).toBe('Petunjuk server');
  });

  it('derives hint use server-side and rebuilds projections after final V2 answer', async () => {
    process.env.LEARNING_V2_ENABLED = 'true';
    repository.getOwnedSession.mockResolvedValue({
      id: 'session-v2',
      target: 'cpns',
      evidence_capture_version: 'compatibility-practice-v2',
    } as any);
    repository.submitLearningV2Answer.mockResolvedValue({
      canonicalAttemptId: 'attempt-1',
      progress: { isFinished: true },
    });

    await service.submitAnswer('user-1', 'session-v2', {
      idempotencyKey: 'answer-v2-1',
      sessionQuestionId: 'sq-1',
      selectedOptionIndex: 2,
      responseTimeMs: 1200,
    });

    expect(repository.submitLearningV2Answer).toHaveBeenCalledWith({
      userId: 'user-1',
      sessionId: 'session-v2',
      idempotencyKey: 'answer-v2-1',
      sessionQuestionId: 'sq-1',
      selectedOptionIndex: 2,
      responseTimeMs: 1200,
    });
    expect(learningProjections.rebuildAndDrainUser).toHaveBeenCalledWith(
      'user-1',
      'cpns',
    );
  });
});
