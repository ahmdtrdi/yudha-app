import {
  ConflictException,
  Inject,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Response } from 'express';
import { StartInterviewSessionDto } from './dto/start-interview-session.dto';
import { SubmitInterviewTurnDto } from './dto/submit-interview-turn.dto';
import { INTERVIEW_LLM_CLIENT } from './interview.constants';
import {
  InterviewEvaluation,
  InterviewFinalSummary,
  InterviewSession,
  InterviewTurn,
} from './interview.types';
import type { InterviewLlmClient } from './interview.types';
import { InterviewSessionRepository } from './repositories/interview-session.repository';
import { CompanyContextService } from './services/company-context.service';
import { InterviewInputValidator } from './services/interview-input-validator.service';
import { InterviewSummaryService } from './services/interview-summary.service';

@Injectable()
export class InterviewService {
  private readonly maxTurns: number;
  private readonly defaultLanguage: string;
  private readonly wordStreamingDelayMs: number;

  constructor(
    private readonly repository: InterviewSessionRepository,
    private readonly companyContextService: CompanyContextService,
    private readonly inputValidator: InterviewInputValidator,
    private readonly summaryService: InterviewSummaryService,
    configService: ConfigService,
    @Inject(INTERVIEW_LLM_CLIENT)
    private readonly llmClient: InterviewLlmClient,
  ) {
    this.maxTurns = this.getPositiveInteger(
      configService,
      'INTERVIEW_MAX_TURNS',
      5,
    );
    this.defaultLanguage = configService.get<string>(
      'INTERVIEW_RESPONSE_LANGUAGE',
      'id',
    );
    this.wordStreamingDelayMs = Number(
      configService.get<string>(
        'INTERVIEW_WORD_STREAMING_DELAY_MS',
        process.env.NODE_ENV === 'test' ? '0' : '30',
      ),
    );
  }

  async startSession(userId: string, input: StartInterviewSessionDto) {
    this.inputValidator.validateStartSession(input);

    const contextSnapshot = await this.companyContextService.resolveSnapshot(
      input.companyId.trim(),
    );
    const session = await this.repository.createSession({
      userId,
      companyId: contextSnapshot.companyId,
      targetRole: input.targetRole.trim(),
      mode: input.mode.trim(),
      language: input.language?.trim() || this.defaultLanguage,
      responseStyle: input.responseStyle ?? 'text',
      contextSnapshot,
    });
    const openingQuestion = await this.repository.addQuestion(
      session.id,
      this.buildOpeningQuestion(
        contextSnapshot.companyName,
        session.targetRole,
      ),
    );

    return {
      sessionId: session.id,
      status: session.status,
      companyId: session.companyId,
      responseStyle: session.responseStyle,
      openingQuestion: this.toQuestionResponse(
        openingQuestion,
        session.responseStyle,
      ),
    };
  }

  async listSessions(userId: string) {
    const sessions = await this.repository.listOwnedSessions(userId);

    return {
      sessions: sessions.map((session) => ({
        sessionId: session.id,
        status: session.status,
        companyId: session.companyId,
        targetRole: session.targetRole,
        mode: session.mode,
        language: session.language,
        responseStyle: session.responseStyle,
        finalSummary: session.finalSummary,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
      })),
    };
  }

  async submitAnswer(
    userId: string,
    sessionId: string,
    input: SubmitInterviewTurnDto,
  ) {
    this.inputValidator.validateSubmitTurn(input);

    const session = await this.repository.getOwnedSession(sessionId, userId);
    this.assertActive(session);

    const answerClaim = await this.repository.claimAnswer(
      session.id,
      input.answer.text.trim(),
      input.idempotencyKey.trim(),
    );

    if (!answerClaim.isNew) {
      return this.buildReplayResponse(session, answerClaim.turn);
    }

    const answerTurn = answerClaim.turn;
    let isAnswerCompleted = false;

    try {
      const turns = await this.repository.listTurns(session.id);
      const answerCount = turns.filter(
        (turn) => turn.role === 'answer' && turn.processingStatus !== 'failed',
      ).length;
      const latestQuestion = this.findQuestionBeforeAnswer(
        turns,
        answerTurn.id,
      );
      const recentTurns = await this.repository.listRecentTurns(session.id);
      const evaluation = await this.llmClient.evaluateAnswer({
        companyContext: session.contextSnapshot,
        targetRole: session.targetRole,
        mode: session.mode,
        language: session.language,
        rollingSummary: session.rollingSummary,
        recentTurns: recentTurns.filter((turn) => turn.id !== answerTurn.id),
        latestQuestion: latestQuestion.content,
        latestAnswer: answerTurn.content,
      });
      const shouldEndSession =
        evaluation.shouldEndSession || answerCount >= this.maxTurns;
      const completedEvaluation = {
        ...evaluation,
        shouldEndSession,
        endReason: shouldEndSession
          ? evaluation.endReason || 'Maximum interview turns reached.'
          : evaluation.endReason,
      };

      await this.repository.completeAnswer(answerTurn.id, completedEvaluation);
      isAnswerCompleted = true;
      await this.repository.updateSessionSummary(
        session.id,
        this.summaryService.appendRollingSummary(
          session.rollingSummary,
          completedEvaluation,
        ),
      );

      const nextQuestion = shouldEndSession
        ? null
        : await this.repository.addQuestion(
            session.id,
            completedEvaluation.nextQuestion,
            answerTurn.id,
          );
      const finalSummary = shouldEndSession
        ? this.buildFinalSummary(await this.repository.listTurns(session.id))
        : null;

      if (finalSummary) {
        await this.repository.completeSession(session.id, finalSummary);
      }

      return this.buildTurnResponse(
        session,
        completedEvaluation,
        nextQuestion,
        finalSummary,
      );
    } catch (error) {
      if (!isAnswerCompleted) {
        await this.repository.failAnswer(answerTurn.id);
      }

      throw error;
    }
  }

  async submitAnswerStream(
    userId: string,
    sessionId: string,
    input: SubmitInterviewTurnDto,
    res: Response,
  ) {
    this.inputValidator.validateSubmitTurn(input);

    const session = await this.repository.getOwnedSession(sessionId, userId);
    this.assertActive(session);

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    if (typeof (res as any).flushHeaders === 'function') {
      (res as any).flushHeaders();
    }

    const answerClaim = await this.repository.claimAnswer(
      session.id,
      input.answer.text.trim(),
      input.idempotencyKey.trim(),
    );

    if (!answerClaim.isNew) {
      return this.streamReplayResponse(
        session,
        answerClaim.turn,
        input.idempotencyKey.trim(),
        res,
      );
    }

    const answerTurn = answerClaim.turn;
    let sequence = 0;
    const sendEvent = (event: string, payload: Record<string, unknown>) => {
      const data = JSON.stringify({
        sessionId: session.id,
        requestId: input.idempotencyKey.trim(),
        sequence: sequence++,
        ...payload,
      });
      res.write(`event: ${event}\ndata: ${data}\n\n`);
    };

    let isAnswerCompleted = false;

    try {
      sendEvent('started', { answerTurnId: answerTurn.id });

      const turns = await this.repository.listTurns(session.id);
      const answerCount = turns.filter(
        (turn) => turn.role === 'answer' && turn.processingStatus !== 'failed',
      ).length;
      const latestQuestion = this.findQuestionBeforeAnswer(
        turns,
        answerTurn.id,
      );
      const recentTurns = await this.repository.listRecentTurns(session.id);
      const evaluation = await this.llmClient.evaluateAnswer({
        companyContext: session.contextSnapshot,
        targetRole: session.targetRole,
        mode: session.mode,
        language: session.language,
        rollingSummary: session.rollingSummary,
        recentTurns: recentTurns.filter((turn) => turn.id !== answerTurn.id),
        latestQuestion: latestQuestion.content,
        latestAnswer: answerTurn.content,
      });
      const shouldEndSession =
        evaluation.shouldEndSession || answerCount >= this.maxTurns;
      const completedEvaluation = {
        ...evaluation,
        shouldEndSession,
        endReason: shouldEndSession
          ? evaluation.endReason || 'Maximum interview turns reached.'
          : evaluation.endReason,
      };

      await this.repository.completeAnswer(answerTurn.id, completedEvaluation);
      isAnswerCompleted = true;
      await this.repository.updateSessionSummary(
        session.id,
        this.summaryService.appendRollingSummary(
          session.rollingSummary,
          completedEvaluation,
        ),
      );

      if (!shouldEndSession && completedEvaluation.nextQuestion) {
        const words =
          completedEvaluation.nextQuestion.match(/\S+\s*/g) || [
            completedEvaluation.nextQuestion,
          ];
        for (const word of words) {
          sendEvent('delta', { delta: word });
          if (this.wordStreamingDelayMs > 0) {
            await new Promise((resolve) =>
              setTimeout(resolve, this.wordStreamingDelayMs),
            );
          }
        }
      }

      if (session.mode === 'coaching') {
        sendEvent('evaluation', { evaluation: completedEvaluation });
      }

      const nextQuestion = shouldEndSession
        ? null
        : await this.repository.addQuestion(
            session.id,
            completedEvaluation.nextQuestion,
            answerTurn.id,
          );
      const finalSummary = shouldEndSession
        ? this.buildFinalSummary(await this.repository.listTurns(session.id))
        : null;

      if (finalSummary) {
        await this.repository.completeSession(session.id, finalSummary);
      }

      if (nextQuestion) {
        sendEvent('question', {
          question: this.toQuestionResponse(
            nextQuestion,
            session.responseStyle,
          ),
        });
      }

      sendEvent('completed', {
        status: shouldEndSession ? 'completed' : 'active',
        finalSummary: shouldEndSession ? finalSummary : undefined,
      });
      res.end();
    } catch (error: any) {
      if (!isAnswerCompleted) {
        await this.repository.failAnswer(answerTurn.id);
      }

      sendEvent('error', {
        error: {
          code:
            error?.status === 504 || error?.name === 'TimeoutError'
              ? 'PROVIDER_UNAVAILABLE'
              : 'INTERNAL_SERVER_ERROR',
          message: error?.message || 'Streaming turn evaluation failed.',
          details: { recoverable: true },
        },
      });
      res.end();
    }
  }

  private async streamReplayResponse(
    session: InterviewSession,
    answer: InterviewTurn,
    requestId: string,
    res: Response,
  ) {
    let sequence = 0;
    const sendEvent = (event: string, payload: Record<string, unknown>) => {
      const data = JSON.stringify({
        sessionId: session.id,
        requestId,
        sequence: sequence++,
        ...payload,
      });
      res.write(`event: ${event}\ndata: ${data}\n\n`);
    };

    if (answer.processingStatus === 'pending') {
      sendEvent('error', {
        error: {
          code: 'CONFLICT',
          message: 'Interview answer is still processing.',
          details: { recoverable: true },
        },
      });
      res.end();
      return;
    }

    if (answer.processingStatus === 'failed' || !answer.evaluation) {
      sendEvent('error', {
        error: {
          code: 'PROVIDER_UNAVAILABLE',
          message:
            'The previous interview answer processing failed. Submit a new request.',
          details: { recoverable: true },
        },
      });
      res.end();
      return;
    }

    sendEvent('started', { answerTurnId: answer.id });

    const evaluation = answer.evaluation;
    const shouldEndSession = evaluation.shouldEndSession;

    if (!shouldEndSession && evaluation.nextQuestion) {
      const words = evaluation.nextQuestion.match(/\S+\s*/g) || [
        evaluation.nextQuestion,
      ];
      for (const word of words) {
        sendEvent('delta', { delta: word });
      }
    }

    if (session.mode === 'coaching') {
      sendEvent('evaluation', { evaluation });
    }

    const nextQuestion = shouldEndSession
      ? null
      : await this.repository.addQuestion(
          session.id,
          evaluation.nextQuestion,
          answer.id,
        );
    let finalSummary = session.finalSummary;

    if (shouldEndSession && session.status === 'active') {
      const turns = await this.repository.listTurns(session.id);
      finalSummary = this.buildFinalSummary(turns);
      await this.repository.completeSession(session.id, finalSummary);
    }

    if (nextQuestion) {
      sendEvent('question', {
        question: this.toQuestionResponse(nextQuestion, session.responseStyle),
      });
    }

    sendEvent('completed', {
      status: shouldEndSession ? 'completed' : 'active',
      finalSummary: shouldEndSession ? finalSummary : undefined,
    });
    res.end();
  }

  async getSession(userId: string, sessionId: string) {
    const session = await this.repository.getOwnedSession(sessionId, userId);
    const turns = await this.repository.listTurns(session.id);

    return {
      sessionId: session.id,
      status: session.status,
      companyId: session.companyId,
      targetRole: session.targetRole,
      mode: session.mode,
      responseStyle: session.responseStyle,
      turns: turns.map((turn) => ({
        turnId: turn.id,
        role: turn.role,
        text: turn.content,
        evaluation:
          session.mode === 'coaching' || session.status === 'completed'
            ? turn.evaluation
            : undefined,
        createdAt: turn.createdAt,
      })),
      finalSummary: session.finalSummary,
    };
  }

  async completeSession(userId: string, sessionId: string) {
    const session = await this.repository.getOwnedSession(sessionId, userId);

    if (session.status === 'completed' && session.finalSummary) {
      return {
        sessionId: session.id,
        status: session.status,
        finalSummary: session.finalSummary,
      };
    }

    this.assertActive(session);

    const turns = await this.repository.listTurns(session.id);
    const finalSummary = this.buildFinalSummary(turns);
    await this.repository.completeSession(session.id, finalSummary);

    return {
      sessionId: session.id,
      status: 'completed',
      finalSummary,
    };
  }

  private async buildReplayResponse(
    session: InterviewSession,
    answer: InterviewTurn,
  ) {
    if (answer.processingStatus === 'pending') {
      throw new ConflictException('Interview answer is still processing.');
    }

    if (answer.processingStatus === 'failed' || !answer.evaluation) {
      throw new ServiceUnavailableException(
        'The previous interview answer processing failed. Submit a new request.',
      );
    }

    const shouldEndSession = answer.evaluation.shouldEndSession;
    const nextQuestion = shouldEndSession
      ? null
      : await this.repository.addQuestion(
          session.id,
          answer.evaluation.nextQuestion,
          answer.id,
        );
    let finalSummary = session.finalSummary;

    if (shouldEndSession && session.status === 'active') {
      const turns = await this.repository.listTurns(session.id);
      finalSummary = this.buildFinalSummary(turns);
      await this.repository.completeSession(session.id, finalSummary);
    }

    return this.buildTurnResponse(
      session,
      answer.evaluation,
      nextQuestion,
      finalSummary,
    );
  }

  private buildTurnResponse(
    session: InterviewSession,
    evaluation: InterviewEvaluation,
    nextQuestion: InterviewTurn | null,
    finalSummary: InterviewFinalSummary | null,
  ) {
    const isCompleted = evaluation.shouldEndSession;

    return {
      sessionId: session.id,
      status: isCompleted ? 'completed' : 'active',
      responseStyle: session.responseStyle,
      evaluation: session.mode === 'coaching' ? evaluation : undefined,
      nextQuestion: nextQuestion
        ? this.toQuestionResponse(nextQuestion, session.responseStyle)
        : null,
      finalSummary: isCompleted ? finalSummary : undefined,
    };
  }

  private assertActive(session: InterviewSession): void {
    if (session.status !== 'active') {
      throw new ConflictException('Interview session is not active.');
    }
  }

  private findQuestionBeforeAnswer(
    turns: InterviewTurn[],
    answerTurnId: string,
  ): InterviewTurn {
    const answerIndex = turns.findIndex((turn) => turn.id === answerTurnId);
    for (let index = answerIndex - 1; index >= 0; index -= 1) {
      if (turns[index].role === 'question') {
        return turns[index];
      }
    }

    throw new ConflictException('Interview session has no active question.');
  }

  private buildFinalSummary(turns: InterviewTurn[]): InterviewFinalSummary {
    const evaluations = turns
      .map((turn) => turn.evaluation)
      .filter((evaluation): evaluation is InterviewEvaluation =>
        Boolean(evaluation),
      );

    return this.summaryService.buildFinalSummary(evaluations);
  }

  private buildOpeningQuestion(
    companyName: string,
    targetRole: string,
    candidateName?: string,
  ): string {
    const greeting = candidateName ? `Halo ${candidateName}! ` : 'Halo! ';
    return [
      `${greeting}Selamat datang di simulasi wawancara kerja ${companyName}.`,
      `Saya adalah AI Interviewer Anda untuk posisi ${targetRole}.`,
      `Senang bisa berdiskusi dengan Anda hari ini. Sebagai permulaan, silakan perkenalkan diri Anda dan jelaskan latar belakang serta motivasi Anda melamar posisi ini.`,
    ].join(' ');
  }

  private toQuestionResponse(question: InterviewTurn, responseStyle: string) {
    return {
      turnId: question.id,
      text: question.content,
      audioAvailable: responseStyle === 'voice',
    };
  }

  private getPositiveInteger(
    configService: ConfigService,
    key: string,
    fallback: number,
  ): number {
    const value = Number(configService.get<string>(key, String(fallback)));
    if (!Number.isInteger(value) || value <= 0) {
      throw new Error(`${key} must be a positive integer.`);
    }

    return value;
  }
}
