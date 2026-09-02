import { BadRequestException } from '@nestjs/common';
import { SoloRepository } from './solo.repository';
import { SoloService } from './solo.service';

describe('SoloService Learning V2 alignment', () => {
  let repository: jest.Mocked<SoloRepository>;
  let service: SoloService;

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
    service = new SoloService(repository);
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

  it.each([
    ['focus', { type: 'balanced' }],
    ['standard', { type: 'recommended' }],
  ])(
    'rejects unavailable %s / %p combinations',
    async (mechanicMode, questionSelection) => {
      await expect(
        service.createSession('user-1', {
          idempotencyKey: 'create-1',
          mechanicMode,
          questionCount: 20,
          questionSelection,
          characterId: 'character-basic-squire',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    },
  );

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
});
