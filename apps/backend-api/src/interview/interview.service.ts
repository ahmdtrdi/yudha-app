import {
  ConflictException,
  Inject,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
  ): string {
    return [
      'Ceritakan tentang diri Anda dan alasan Anda tertarik melamar sebagai',
      `${targetRole} di ${companyName}.`,
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
