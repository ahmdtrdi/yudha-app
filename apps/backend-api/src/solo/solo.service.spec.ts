import { BadRequestException } from '@nestjs/common';
import { SoloRepository } from './solo.repository';
import { SoloService } from './solo.service';

describe('SoloService Learning V2 alignment', () => {
  let repository: jest.Mocked<SoloRepository>;
  let learningProjections: { rebuildAndDrainUser: jest.Mock };
  let service: SoloService;
  const previousFlag = process.env.LEARNING_V2_ENABLED;

  beforeEach(() => {
    repository = {
      createSession: jest.fn(),
      getSession: jest.fn(),
      getActiveSession: jest.fn(),
      openQuestion: jest.fn(),
      requestHint: jest.fn(),
      submitAnswer: jest.fn(),
      finishSession: jest.fn(),
      getEconomyState: jest.fn().mockResolvedValue({
        energy: { balance: 8, cap: 10, unlimited: false },
      }),
    } as unknown as jest.Mocked<SoloRepository>;
    learningProjections = { rebuildAndDrainUser: jest.fn() };
    service = new SoloService(repository, learningProjections as any);
  });

  afterEach(() => {
    if (previousFlag === undefined) delete process.env.LEARNING_V2_ENABLED;
    else process.env.LEARNING_V2_ENABLED = previousFlag;
  });

  it('creates the approved Balanced + Standard slice', async () => {
    repository.createSession.mockResolvedValue({ sessionId: 'solo-1' });
    await service.createSession('user-1', {
      idempotencyKey: 'create-1',
      mechanicMode: 'standard',
      questionCount: 20,
      questionSelection: { type: 'balanced' },
      characterId: 'character-basic-squire',
    });
    expect(repository.createSession).toHaveBeenCalledWith({
      userId: 'user-1',
      idempotencyKey: 'create-1',
      mechanicMode: 'standard',
      questionSelection: 'balanced',
      questionCount: 20,
      characterId: 'character-basic-squire',
    });
  });

  it.each(['focus', 'speed'] as const)(
    'creates %s sessions with balanced selection',
    async (mechanicMode) => {
      repository.createSession.mockResolvedValue({ sessionId: `solo-${mechanicMode}` });
      await service.createSession('user-1', {
        idempotencyKey: `create-${mechanicMode}`,
        mechanicMode,
        questionCount: 20,
        questionSelection: { type: 'balanced' },
        characterId: 'character-basic-squire',
      });
      expect(repository.createSession).toHaveBeenCalledWith({
        userId: 'user-1',
        idempotencyKey: `create-${mechanicMode}`,
        mechanicMode,
        questionSelection: 'balanced',
        questionCount: 20,
        characterId: 'character-basic-squire',
      });
    },
  );

  it('creates recommended sessions with recommendationId', async () => {
    repository.createSession.mockResolvedValue({ sessionId: 'solo-rec' });
    await service.createSession('user-1', {
      idempotencyKey: 'create-rec',
      mechanicMode: 'focus',
      questionCount: 20,
      questionSelection: { type: 'recommended' },
      recommendationId: 'rec-123',
      characterId: 'character-basic-squire',
    });
    expect(repository.createSession).toHaveBeenCalledWith({
      userId: 'user-1',
      idempotencyKey: 'create-rec',
      mechanicMode: 'focus',
      questionSelection: 'recommended',
      questionCount: 20,
      characterId: 'character-basic-squire',
      recommendationId: 'rec-123',
    });
  });

  it('rejects unsupported question selection combinations', async () => {
    await expect(
      service.createSession('user-1', {
        idempotencyKey: 'create-custom',
        mechanicMode: 'standard',
        questionCount: 20,
        questionSelection: { type: 'custom', skillIds: ['skill-1'] },
        characterId: 'character-basic-squire',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('submits null as an authoritative timeout reconciliation', async () => {
    repository.submitAnswer.mockResolvedValue({
      answerResult: { timedOut: true },
    });
    await service.submitAnswer('user-1', 'solo-1', {
      idempotencyKey: 'answer-1',
      sessionQuestionId: 'sq-1',
      selectedOptionIndex: null,
    });
    expect(repository.submitAnswer).toHaveBeenCalledWith(
      expect.objectContaining({
        selectedOptionIndex: null,
        clientActiveResponseTimeMs: null,
        backgroundDurationMs: null,
      }),
    );
  });

  it('requests hints through the authoritative endpoint', async () => {
    repository.requestHint.mockResolvedValue({ hint: 'Mulai dari selisih.' });
    await service.requestHint('user-1', 'solo-1', 'sq-2', {
      idempotencyKey: 'hint-1',
    });
    expect(repository.requestHint).toHaveBeenCalledWith(
      'user-1',
      'solo-1',
      'sq-2',
      'hint-1',
    );
  });

  it('forwards validated client timing without client-authored hint state', async () => {
    repository.submitAnswer.mockResolvedValue({
      answerResult: { isCorrect: true },
    });
    await service.submitAnswer('user-1', 'solo-1', {
      idempotencyKey: 'answer-1',
      sessionQuestionId: 'sq-2',
      selectedOptionIndex: 1,
      clientActiveResponseTimeMs: 4100,
      backgroundDurationMs: 900,
    });
    expect(repository.submitAnswer).toHaveBeenCalledWith(
      expect.objectContaining({
        clientActiveResponseTimeMs: 4100,
        backgroundDurationMs: 900,
      }),
    );
  });

  it('projects canonical evidence immediately when Solo completes', async () => {
    process.env.LEARNING_V2_ENABLED = 'true';
    repository.submitAnswer.mockResolvedValue({
      status: 'completed',
      target: 'cpns',
      answerResult: { isCorrect: true },
    });

    await service.submitAnswer('user-1', 'solo-1', {
      idempotencyKey: 'answer-final',
      sessionQuestionId: 'sq-20',
      selectedOptionIndex: 1,
    });

    expect(learningProjections.rebuildAndDrainUser).toHaveBeenCalledWith(
      'user-1',
      'cpns',
    );
  });

  it('does not rebuild the dashboard projection for an active Solo session', async () => {
    process.env.LEARNING_V2_ENABLED = 'true';
    repository.submitAnswer.mockResolvedValue({
      status: 'active',
      target: 'cpns',
      answerResult: { isCorrect: true },
    });

    await service.submitAnswer('user-1', 'solo-1', {
      idempotencyKey: 'answer-1',
      sessionQuestionId: 'sq-1',
      selectedOptionIndex: 1,
    });

    expect(learningProjections.rebuildAndDrainUser).not.toHaveBeenCalled();
  });

  it('projects partial canonical evidence when Solo is stopped', async () => {
    process.env.LEARNING_V2_ENABLED = 'true';
    repository.finishSession.mockResolvedValue({
      status: 'stopped',
      target: 'bumn',
    });

    await service.finishSession('user-1', 'solo-1', {
      idempotencyKey: 'finish-1',
    });

    expect(learningProjections.rebuildAndDrainUser).toHaveBeenCalledWith(
      'user-1',
      'bumn',
    );
  });
});
