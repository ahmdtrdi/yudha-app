import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PracticeRepository } from './practice.repository';
import { PracticeService } from './practice.service';
import type {
  PracticeAnswerRow,
  PracticeQuestionRow,
  PracticeSessionQuestionRow,
  PracticeSessionRow,
} from './practice.types';

describe('PracticeService', () => {
  let repository: jest.Mocked<PracticeRepository>;
  let service: PracticeService;

  beforeEach(() => {
    repository = {
      getUserTarget: jest.fn(),
      listActiveQuestions: jest.fn(),
      createSession: jest.fn(),
      addSessionQuestions: jest.fn(),
      getOwnedSession: jest.fn(),
      listSessionQuestions: jest.fn(),
      listQuestionsByIds: jest.fn(),
      listAnswersForSession: jest.fn(),
      insertAnswer: jest.fn(),
      updateOwnedSession: jest.fn(),
      listOwnedSessions: jest.fn(),
      listRecentOwnedSessions: jest.fn(),
      getActiveOwnedSession: jest.fn(),
    } as unknown as jest.Mocked<PracticeRepository>;
    service = new PracticeService(repository);
  });

  it('creates a session with five safe questions', async () => {
    const questions = Array.from({ length: 5 }, (_, index) =>
      question(`q-${index + 1}`),
    );
    repository.getUserTarget.mockResolvedValue('cpns');
    repository.listActiveQuestions.mockResolvedValue(questions);
    repository.createSession.mockResolvedValue(session());
    repository.addSessionQuestions.mockResolvedValue(
      questions.map((item, index) => sessionQuestion(item.id, index + 1)),
    );

    const result = await service.createSession('user-1', {
      category: 'tiu',
    });

    expect(repository.createSession).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        target: 'cpns',
        category: 'tiu',
        total_questions: 5,
      }),
    );
    expect(result.data.questions).toHaveLength(5);
    expect(result.data.questions[0]).not.toHaveProperty('correctOptionIndex');
    expect(result.data.questions[0]).not.toHaveProperty('explanation');
  });

  it('rejects session creation when fewer than five questions are eligible', async () => {
    repository.getUserTarget.mockResolvedValue('cpns');
    repository.listActiveQuestions.mockResolvedValue([
      question('q-1'),
      question('q-2'),
    ]);

    await expect(
      service.createSession('user-1', { category: 'tiu' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('submits an answer only after loading the owned session', async () => {
    const ownedSession = session({ total_questions: 1 });
    const ownedQuestion = question('q-1');
    const ownedSessionQuestion = sessionQuestion('q-1', 1);
    const savedAnswer = answer(ownedSessionQuestion.id, true);

    repository.getOwnedSession.mockResolvedValue(ownedSession);
    repository.listSessionQuestions.mockResolvedValue([ownedSessionQuestion]);
    repository.listQuestionsByIds.mockResolvedValue([ownedQuestion]);
    repository.listAnswersForSession
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([savedAnswer]);
    repository.insertAnswer.mockResolvedValue(savedAnswer);

    const result = await service.submitAnswer('user-1', 'session-1', {
      sessionQuestionId: ownedSessionQuestion.id,
      selectedOptionIndex: 2,
    });

    expect(repository.getOwnedSession).toHaveBeenCalledWith(
      'session-1',
      'user-1',
    );
    expect(repository.insertAnswer).toHaveBeenCalledWith(
      expect.objectContaining({
        session_id: 'session-1',
        user_id: 'user-1',
        session_question_id: ownedSessionQuestion.id,
        is_correct: true,
      }),
    );
    expect(repository.updateOwnedSession).toHaveBeenCalledWith(
      'session-1',
      'user-1',
      expect.objectContaining({ finished_at: expect.any(String) }),
    );
    expect(result.data.correctOptionIndex).toBe(2);
    expect(result.data.progress.isFinished).toBe(true);
  });

  it('rejects answers for questions outside the owned session', async () => {
    repository.getOwnedSession.mockResolvedValue(session());
    repository.listSessionQuestions.mockResolvedValue([]);
    repository.listAnswersForSession.mockResolvedValue([]);
    repository.listQuestionsByIds.mockResolvedValue([]);

    await expect(
      service.submitAnswer('user-1', 'session-1', {
        sessionQuestionId: 'other-session-question',
        selectedOptionIndex: 2,
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(repository.insertAnswer).not.toHaveBeenCalled();
  });
});

function session(
  overrides: Partial<PracticeSessionRow> = {},
): PracticeSessionRow {
  return {
    id: 'session-1',
    user_id: 'user-1',
    target: 'cpns',
    category: 'tiu',
    subcategory: null,
    total_questions: 5,
    correct_count: 0,
    total_score: 0,
    accuracy: 0,
    started_at: '2026-06-04T00:00:00.000Z',
    finished_at: null,
    ...overrides,
  };
}

function question(id: string): PracticeQuestionRow {
  return {
    id,
    target: 'cpns',
    category: 'tiu',
    subcategory: null,
    prompt: '2, 4, 6, ...',
    options: ['7', '8', '9', '10'],
    correct_option_index: 2,
    explanation: 'The sequence increases by 2.',
    difficulty: 'easy',
    weight: 1,
    effect: 'damage',
    damage_value: 10,
    heal_value: 0,
    time_limit_seconds: 30,
    hint: null,
  };
}

function sessionQuestion(
  questionId: string,
  order: number,
): PracticeSessionQuestionRow {
  return {
    id: `session-question-${order}`,
    session_id: 'session-1',
    question_id: questionId,
    question_order: order,
    created_at: '2026-06-04T00:00:00.000Z',
  };
}

function answer(
  sessionQuestionId: string,
  isCorrect: boolean,
): PracticeAnswerRow {
  return {
    id: 'answer-1',
    session_id: 'session-1',
    user_id: 'user-1',
    session_question_id: sessionQuestionId,
    question_id: 'q-1',
    question_order: 1,
    selected_option_index: 2,
    is_correct: isCorrect,
    used_hint: false,
    response_time_ms: null,
    answered_at: '2026-06-04T00:00:01.000Z',
    created_at: '2026-06-04T00:00:01.000Z',
  };
}
