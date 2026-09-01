import { BadRequestException } from '@nestjs/common';
import { SoloRepository } from './solo.repository';
import { SoloService } from './solo.service';

describe('SoloService Commit 5', () => {
  let repository: jest.Mocked<SoloRepository>;
  let service: SoloService;

  beforeEach(() => {
    repository = {
      createSession: jest.fn(),
      getSession: jest.fn(),
      getActiveSession: jest.fn(),
      openQuestion: jest.fn(),
      submitAnswer: jest.fn(),
      finishSession: jest.fn(),
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
      expect.objectContaining({ selectedOptionIndex: null }),
    );
  });
});
