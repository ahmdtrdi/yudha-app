import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CreatePracticeSessionDto } from './dto/create-practice-session.dto';
import { PracticeHistoryQueryDto } from './dto/practice-history-query.dto';
import { SubmitPracticeAnswerDto } from './dto/submit-practice-answer.dto';
import { FinishPracticeSessionDto } from './dto/finish-practice-session.dto';
import { PracticeRepository } from './practice.repository';
import {
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
    const category = this.optionalText(input.category, 'category', 100);
    const subcategory = this.optionalText(
      input.subcategory,
      'subcategory',
      100,
    );
    if (subcategory && !category) {
      throw new BadRequestException('category is required with subcategory.');
    }
    const data = await this.repository.createTransactionalSession(
      userId,
      category,
      subcategory,
    );
    return { data };
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
    const idempotencyKey = this.requireText(
      input.idempotencyKey,
      'idempotencyKey',
      160,
    );
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
    if (typeof input.usedHint !== 'boolean') {
      throw new BadRequestException('usedHint must be a boolean.');
    }
    const data = await this.repository.submitTransactionalAnswer({
      userId,
      sessionId,
      idempotencyKey,
      sessionQuestionId,
      selectedOptionIndex,
      responseTimeMs,
      usedHint: input.usedHint,
    });
    return { data };
  }

  async finishSession(
    userId: string,
    sessionId: string,
    input: FinishPracticeSessionDto,
  ) {
    const idempotencyKey = this.requireText(
      input.idempotencyKey,
      'idempotencyKey',
      160,
    );
    const data = await this.repository.finishTransactionalSession(
      userId,
      sessionId,
      idempotencyKey,
    );
    return { data };
  }

  async getHistory(userId: string, query: PracticeHistoryQueryDto) {
    const target = await this.repository.getUserTarget(userId);
    const limit = this.parsePagination(query.limit, 20, 1, 50);
    const offset = this.parsePagination(query.offset, 0, 0, 10000);
    const filters = {
      category: this.optionalText(query.category, 'category', 100) ?? undefined,
      subcategory:
        this.optionalText(query.subcategory, 'subcategory', 100) ?? undefined,
      limit,
      offset,
    };
    const [sessions, total] = await Promise.all([
      this.repository.listOwnedSessions(userId, target, filters),
      this.repository.countOwnedSessions(userId, target, filters),
    ]);
    const answerCounts = await this.countAnswersBySession(userId, sessions);

    return {
      data: {
        items: sessions.map((session) =>
          this.toSessionSummary(session, answerCounts.get(session.id) ?? 0),
        ),
        limit,
        offset,
        total,
      },
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
      const current = categories.get(session.category) ?? {
        total: 0,
        count: 0,
      };
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
      correctOptionIndex: answer ? detail.question.correct_option_index : null,
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

  private requireText(
    value: unknown,
    field: string,
    maxLength: number,
  ): string {
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
      value > 5
    ) {
      throw new BadRequestException(
        'selectedOptionIndex must be an integer between 0 and 5.',
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
      throw new BadRequestException(`${field} must be a non-negative integer.`);
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
