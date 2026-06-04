import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CreatePracticeSessionDto } from './dto/create-practice-session.dto';
import { PracticeHistoryQueryDto } from './dto/practice-history-query.dto';
import { SubmitPracticeAnswerDto } from './dto/submit-practice-answer.dto';
import { PracticeRepository } from './practice.repository';
import {
  PRACTICE_QUESTION_COUNT,
  PracticeAnswerRow,
  PracticeQuestionRow,
  PracticeSessionQuestionRow,
  PracticeSessionRow,
  SessionQuestionDetail,
} from './practice.types';

@Injectable()
export class PracticeService {
  constructor(private readonly repository: PracticeRepository) {}

  async getDashboard(userId: string) {
    const target = await this.repository.getUserTarget(userId);
    const [questions, sessions, recentSessions, activeSession] =
      await Promise.all([
        this.repository.listActiveQuestions(target),
        this.repository.listOwnedSessions(userId, target, {
          limit: 1000,
          offset: 0,
        }),
        this.repository.listRecentOwnedSessions(userId, target, 5),
        this.repository.getActiveOwnedSession(userId, target),
      ]);

    const answerCounts = await this.countAnswersBySession(userId, sessions);

    return {
      data: {
        target,
        summary: this.buildSummary(sessions, answerCounts),
        categories: this.buildCategories(questions),
        recentSessions: recentSessions.map((session) =>
          this.toSessionSummary(session, answerCounts.get(session.id) ?? 0),
        ),
        activeSession: activeSession
          ? this.toSessionSummary(
              activeSession,
              answerCounts.get(activeSession.id) ?? 0,
            )
          : null,
      },
    };
  }

  async createSession(userId: string, input: CreatePracticeSessionDto) {
    const category = this.requireText(input.category, 'category', 100);
    const requestedSubcategory = this.optionalText(
      input.subcategory,
      'subcategory',
      100,
    );
    const target = await this.repository.getUserTarget(userId);
    const categoryQuestions = await this.repository.listActiveQuestions(
      target,
      category,
    );

    if (categoryQuestions.length === 0) {
      throw new BadRequestException('Practice category has no questions.');
    }

    const subcategories = this.uniqueNonNull(
      categoryQuestions.map((question) => question.subcategory),
    );
    if (subcategories.length > 0 && !requestedSubcategory) {
      throw new BadRequestException(
        'subcategory is required for this practice category.',
      );
    }
    if (subcategories.length === 0 && requestedSubcategory) {
      throw new BadRequestException(
        'subcategory must be omitted for this practice category.',
      );
    }
    if (
      requestedSubcategory &&
      !subcategories.includes(requestedSubcategory)
    ) {
      throw new BadRequestException(
        'subcategory is not available for this practice category.',
      );
    }

    const eligibleQuestions = requestedSubcategory
      ? categoryQuestions.filter(
          (question) => question.subcategory === requestedSubcategory,
        )
      : categoryQuestions.filter((question) => question.subcategory === null);

    if (eligibleQuestions.length < PRACTICE_QUESTION_COUNT) {
      throw new BadRequestException(
        `At least ${PRACTICE_QUESTION_COUNT} active questions are required.`,
      );
    }

    const selectedQuestions = this.shuffle(eligibleQuestions).slice(
      0,
      PRACTICE_QUESTION_COUNT,
    );
    const session = await this.repository.createSession({
      user_id: userId,
      target,
      category,
      subcategory: requestedSubcategory,
      total_questions: PRACTICE_QUESTION_COUNT,
    });
    const sessionQuestions = await this.repository.addSessionQuestions(
      selectedQuestions.map((question, index) => ({
        session_id: session.id,
        question_id: question.id,
        question_order: index + 1,
      })),
    );

    return {
      data: {
        sessionId: session.id,
        target: session.target,
        category: session.category,
        subcategory: session.subcategory,
        totalQuestions: session.total_questions,
        questions: sessionQuestions.map((sessionQuestion) => {
          const question = this.requireQuestion(
            selectedQuestions,
            sessionQuestion.question_id,
          );
          return this.toSafeQuestion(sessionQuestion, question);
        }),
      },
    };
  }

  async getSession(userId: string, sessionId: string) {
    const session = await this.repository.getOwnedSession(sessionId, userId);
    const details = await this.loadSessionQuestionDetails(session, userId);
    const answeredCount = details.filter((detail) => detail.answer).length;

    return {
      data: {
        sessionId: session.id,
        target: session.target,
        category: session.category,
        subcategory: session.subcategory,
        status: session.finished_at ? 'finished' : 'active',
        totalQuestions: session.total_questions,
        answeredCount,
        correctCount: session.correct_count,
        accuracy: Number(session.accuracy),
        totalScore: session.total_score,
        startedAt: session.started_at,
        finishedAt: session.finished_at,
        questions: details.map((detail) => this.toSessionQuestion(detail)),
      },
    };
  }

  async submitAnswer(
    userId: string,
    sessionId: string,
    input: SubmitPracticeAnswerDto,
  ) {
    const sessionQuestionId = this.requireText(
      input.sessionQuestionId,
      'sessionQuestionId',
      80,
    );
    const selectedOptionIndex = this.requireOptionIndex(
      input.selectedOptionIndex,
    );
    const responseTimeMs = this.optionalNonNegativeInteger(
      input.responseTimeMs,
      'responseTimeMs',
    );
    const session = await this.repository.getOwnedSession(sessionId, userId);
    if (session.finished_at) {
      throw new ConflictException('Practice session is already finished.');
    }

    const details = await this.loadSessionQuestionDetails(session, userId);
    const detail = details.find(
      (candidate) => candidate.sessionQuestion.id === sessionQuestionId,
    );
    if (!detail) {
      throw new NotFoundException('Practice session question not found.');
    }
    if (detail.answer) {
      throw new ConflictException('Practice question already answered.');
    }

    const isCorrect =
      selectedOptionIndex === detail.question.correct_option_index;
    const scoreGained = isCorrect ? detail.question.weight * 10 : 0;
    await this.repository.insertAnswer({
      session_id: session.id,
      user_id: userId,
      session_question_id: detail.sessionQuestion.id,
      question_id: detail.question.id,
      question_order: detail.sessionQuestion.question_order,
      selected_option_index: selectedOptionIndex,
      is_correct: isCorrect,
      used_hint: Boolean(input.usedHint),
      response_time_ms: responseTimeMs,
    });

    const updatedDetails = await this.loadSessionQuestionDetails(
      session,
      userId,
    );
    const progress = this.calculateProgress(session, updatedDetails);
    await this.repository.updateOwnedSession(session.id, userId, {
      correct_count: progress.correctCount,
      total_score: progress.totalScore,
      accuracy: progress.accuracy,
      finished_at: progress.isFinished ? new Date().toISOString() : null,
    });

    return {
      data: {
        sessionId: session.id,
        sessionQuestionId: detail.sessionQuestion.id,
        questionId: detail.question.id,
        selectedOptionIndex,
        isCorrect,
        correctOptionIndex: detail.question.correct_option_index,
        explanation: detail.question.explanation,
        scoreGained,
        progress,
      },
    };
  }

  async finishSession(userId: string, sessionId: string) {
    const session = await this.repository.getOwnedSession(sessionId, userId);
    const details = await this.loadSessionQuestionDetails(session, userId);
    const progress = this.calculateProgress(session, details, true);
    const finishedAt = session.finished_at ?? new Date().toISOString();

    await this.repository.updateOwnedSession(session.id, userId, {
      correct_count: progress.correctCount,
      total_score: progress.totalScore,
      accuracy: progress.accuracy,
      finished_at: finishedAt,
    });

    return {
      data: {
        sessionId: session.id,
        target: session.target,
        category: session.category,
        subcategory: session.subcategory,
        totalQuestions: session.total_questions,
        answeredCount: progress.answeredCount,
        correctCount: progress.correctCount,
        wrongCount: progress.wrongCount,
        unansweredCount: progress.unansweredCount,
        accuracy: progress.accuracy,
        totalScore: progress.totalScore,
        startedAt: session.started_at,
        finishedAt,
      },
    };
  }

  async getHistory(userId: string, query: PracticeHistoryQueryDto) {
    const target = await this.repository.getUserTarget(userId);
    const limit = this.parsePagination(query.limit, 20, 1, 50);
    const offset = this.parsePagination(query.offset, 0, 0, 10000);
    const sessions = await this.repository.listOwnedSessions(userId, target, {
      category: this.optionalText(query.category, 'category', 100) ?? undefined,
      subcategory:
        this.optionalText(query.subcategory, 'subcategory', 100) ?? undefined,
      limit,
      offset,
    });
    const answerCounts = await this.countAnswersBySession(userId, sessions);

    return {
      data: sessions.map((session) =>
        this.toSessionSummary(session, answerCounts.get(session.id) ?? 0),
      ),
      meta: { limit, offset },
    };
  }

  private async loadSessionQuestionDetails(
    session: PracticeSessionRow,
    userId: string,
  ): Promise<SessionQuestionDetail[]> {
    const [sessionQuestions, answers] = await Promise.all([
      this.repository.listSessionQuestions(session.id),
      this.repository.listAnswersForSession(session.id, userId),
    ]);
    const questions = await this.repository.listQuestionsByIds(
      sessionQuestions.map((sessionQuestion) => sessionQuestion.question_id),
    );

    return sessionQuestions.map((sessionQuestion) => ({
      sessionQuestion,
      question: this.requireQuestion(questions, sessionQuestion.question_id),
      answer:
        answers.find(
          (answer) => answer.session_question_id === sessionQuestion.id,
        ) ?? null,
    }));
  }

  private calculateProgress(
    session: PracticeSessionRow,
    details: SessionQuestionDetail[],
    forceFinished = false,
  ) {
    const answered = details.filter((detail) => detail.answer);
    const correctCount = answered.filter(
      (detail) => detail.answer?.is_correct,
    ).length;
    const totalScore = answered.reduce((score, detail) => {
      return detail.answer?.is_correct
        ? score + detail.question.weight * 10
        : score;
    }, 0);
    const answeredCount = answered.length;
    const accuracy =
      answeredCount === 0
        ? 0
        : Number(((correctCount / answeredCount) * 100).toFixed(2));
    const isFinished =
      forceFinished || answeredCount >= session.total_questions;

    return {
      answeredCount,
      totalQuestions: session.total_questions,
      correctCount,
      wrongCount: answeredCount - correctCount,
      unansweredCount: Math.max(session.total_questions - answeredCount, 0),
      accuracy,
      totalScore,
      isFinished,
    };
  }

  private async countAnswersBySession(
    userId: string,
    sessions: PracticeSessionRow[],
  ): Promise<Map<string, number>> {
    const entries = await Promise.all(
      sessions.map(async (session) => {
        const answers = await this.repository.listAnswersForSession(
          session.id,
          userId,
        );
        return [session.id, answers.length] as const;
      }),
    );

    return new Map(entries);
  }

  private buildCategories(questions: PracticeQuestionRow[]) {
    const groups = new Map<
      string,
      { availableQuestions: number; subcategories: Map<string, number> }
    >();

    for (const question of questions) {
      const group = groups.get(question.category) ?? {
        availableQuestions: 0,
        subcategories: new Map<string, number>(),
      };
      group.availableQuestions += 1;
      if (question.subcategory) {
        group.subcategories.set(
          question.subcategory,
          (group.subcategories.get(question.subcategory) ?? 0) + 1,
        );
      }
      groups.set(question.category, group);
    }

    return [...groups.entries()].map(([category, group]) => ({
      category,
      label: category,
      availableQuestions: group.availableQuestions,
      subcategories: [...group.subcategories.entries()].map(
        ([subcategory, availableQuestions]) => ({
          subcategory,
          availableQuestions,
        }),
      ),
    }));
  }

  private buildSummary(
    sessions: PracticeSessionRow[],
    answerCounts: Map<string, number>,
  ) {
    const totalQuestionsAnswered = [...answerCounts.values()].reduce(
      (total, count) => total + count,
      0,
    );
    const answeredSessions = sessions.filter(
      (session) => (answerCounts.get(session.id) ?? 0) > 0,
    );
    const averageAccuracy =
      answeredSessions.length === 0
        ? 0
        : Number(
            (
              answeredSessions.reduce(
                (total, session) => total + Number(session.accuracy),
                0,
              ) / answeredSessions.length
            ).toFixed(2),
          );
    const categories = new Map<string, { total: number; count: number }>();
    for (const session of answeredSessions) {
      if (!session.category) continue;
      const current = categories.get(session.category) ?? { total: 0, count: 0 };
      current.total += Number(session.accuracy);
      current.count += 1;
      categories.set(session.category, current);
    }
    const ranked = [...categories.entries()]
      .map(([category, value]) => ({
        category,
        average: value.total / value.count,
      }))
      .sort((left, right) => right.average - left.average);

    return {
      totalSessions: sessions.length,
      totalQuestionsAnswered,
      averageAccuracy,
      bestCategory: ranked[0]?.category ?? null,
      weakestCategory: ranked.at(-1)?.category ?? null,
    };
  }

  private toSessionSummary(session: PracticeSessionRow, answeredCount: number) {
    return {
      sessionId: session.id,
      target: session.target,
      category: session.category,
      subcategory: session.subcategory,
      totalQuestions: session.total_questions,
      answeredCount,
      correctCount: session.correct_count,
      wrongCount: Math.max(answeredCount - session.correct_count, 0),
      accuracy: Number(session.accuracy),
      totalScore: session.total_score,
      startedAt: session.started_at,
      finishedAt: session.finished_at,
    };
  }

  private toSafeQuestion(
    sessionQuestion: PracticeSessionQuestionRow,
    question: PracticeQuestionRow,
  ) {
    return {
      sessionQuestionId: sessionQuestion.id,
      questionId: question.id,
      questionOrder: sessionQuestion.question_order,
      target: question.target,
      category: question.category,
      subcategory: question.subcategory,
      prompt: question.prompt,
      options: question.options,
      difficulty: question.difficulty,
      weight: question.weight,
      effect: question.effect,
      damageValue: question.damage_value,
      healValue: question.heal_value,
      timeLimitSeconds: question.time_limit_seconds,
      hint: question.hint,
    };
  }

  private toSessionQuestion(detail: SessionQuestionDetail) {
    const answer = detail.answer;

    return {
      ...this.toSafeQuestion(detail.sessionQuestion, detail.question),
      answered: Boolean(answer),
      selectedOptionIndex: answer?.selected_option_index ?? null,
      isCorrect: answer?.is_correct ?? null,
      correctOptionIndex: answer
        ? detail.question.correct_option_index
        : null,
      explanation: answer ? detail.question.explanation : null,
      usedHint: answer?.used_hint ?? null,
      responseTimeMs: answer?.response_time_ms ?? null,
      answeredAt: answer?.answered_at ?? null,
    };
  }

  private requireQuestion(
    questions: PracticeQuestionRow[],
    questionId: string,
  ): PracticeQuestionRow {
    const question = questions.find((candidate) => candidate.id === questionId);
    if (!question) {
      throw new NotFoundException('Practice question not found.');
    }
    return question;
  }

  private shuffle<T>(values: T[]): T[] {
    const shuffled = [...values];
    for (let index = shuffled.length - 1; index > 0; index -= 1) {
      const swapIndex = Math.floor(Math.random() * (index + 1));
      [shuffled[index], shuffled[swapIndex]] = [
        shuffled[swapIndex],
        shuffled[index],
      ];
    }
    return shuffled;
  }

  private uniqueNonNull(values: Array<string | null>): string[] {
    return [...new Set(values.filter((value): value is string => !!value))];
  }

  private requireText(value: unknown, field: string, maxLength: number): string {
    if (typeof value !== 'string' || value.trim().length === 0) {
      throw new BadRequestException(`${field} must be a non-empty string.`);
    }
    if (value.length > maxLength) {
      throw new BadRequestException(
        `${field} must not exceed ${maxLength} characters.`,
      );
    }
    return value.trim();
  }

  private optionalText(
    value: unknown,
    field: string,
    maxLength: number,
  ): string | null {
    if (value === undefined || value === null || value === '') {
      return null;
    }
    return this.requireText(value, field, maxLength);
  }

  private requireOptionIndex(value: unknown): number {
    if (
      typeof value !== 'number' ||
      !Number.isInteger(value) ||
      value < 0 ||
      value > 3
    ) {
      throw new BadRequestException(
        'selectedOptionIndex must be an integer between 0 and 3.',
      );
    }
    return value;
  }

  private optionalNonNegativeInteger(
    value: unknown,
    field: string,
  ): number | null {
    if (value === undefined || value === null) {
      return null;
    }
    if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
      throw new BadRequestException(
        `${field} must be a non-negative integer.`,
      );
    }
    return value;
  }

  private parsePagination(
    value: string | undefined,
    fallback: number,
    min: number,
    max: number,
  ): number {
    if (value === undefined) {
      return fallback;
    }
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
      throw new BadRequestException(
        `Pagination value must be an integer between ${min} and ${max}.`,
      );
    }
    return parsed;
  }
}
