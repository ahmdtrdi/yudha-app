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
  InterviewDimensions,
  InterviewEvaluation,
  InterviewFinalSummary,
  InterviewSession,
  InterviewTurn,
} from './interview.types';
import type { InterviewLlmClient } from './interview.types';
import { InterviewSessionRepository } from './repositories/interview-session.repository';
import { CompanyContextService } from './services/company-context.service';
import { InterviewInputValidator } from './services/interview-input-validator.service';

const dimensionNames: (keyof InterviewDimensions)[] = [
  'relevance',
  'clarity',
  'structure',
  'confidence',
  'impact',
  'authenticity',
];

@Injectable()
export class InterviewService {
  private readonly maxTurns: number;
  private readonly defaultLanguage: string;

  constructor(
    private readonly repository: InterviewSessionRepository,
    private readonly companyContextService: CompanyContextService,
    private readonly inputValidator: InterviewInputValidator,
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
      openingQuestion: this.toQuestionResponse(openingQuestion),
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
        this.appendRollingSummary(session.rollingSummary, completedEvaluation),
      );

      const nextQuestion = shouldEndSession
        ? null
        : await this.repository.addQuestion(
            session.id,
            completedEvaluation.nextQuestion,
            answerTurn.id,
          );

      if (shouldEndSession) {
        const finalTurns = await this.repository.listTurns(session.id);
        await this.repository.completeSession(
          session.id,
          this.buildFinalSummary(finalTurns),
        );
      }

      return {
        sessionId: session.id,
        status: shouldEndSession ? 'completed' : 'active',
        evaluation: completedEvaluation,
        nextQuestion: nextQuestion
          ? this.toQuestionResponse(nextQuestion)
          : null,
      };
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
      turns: turns.map((turn) => ({
        turnId: turn.id,
        role: turn.role,
        text: turn.content,
        evaluation: turn.evaluation,
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

    if (shouldEndSession && session.status === 'active') {
      const turns = await this.repository.listTurns(session.id);
      await this.repository.completeSession(
        session.id,
        this.buildFinalSummary(turns),
      );
    }

    return {
      sessionId: session.id,
      status: shouldEndSession ? 'completed' : 'active',
      evaluation: answer.evaluation,
      nextQuestion: nextQuestion ? this.toQuestionResponse(nextQuestion) : null,
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

  private appendRollingSummary(
    summary: string,
    evaluation: InterviewEvaluation,
  ): string {
    const line = [
      `Score ${evaluation.overallScore}.`,
      `Strengths: ${evaluation.strengths.join('; ')}.`,
      `Improve: ${evaluation.improvements.join('; ')}.`,
    ].join(' ');

    return [summary, line].filter(Boolean).join('\n').slice(-1600);
  }

  private buildFinalSummary(turns: InterviewTurn[]): InterviewFinalSummary {
    const evaluations = turns
      .map((turn) => turn.evaluation)
      .filter((evaluation): evaluation is InterviewEvaluation =>
        Boolean(evaluation),
      );

    if (evaluations.length === 0) {
      throw new ConflictException(
        'Submit at least one interview answer before completing the session.',
      );
    }

    const dimensions = Object.fromEntries(
      dimensionNames.map((dimension) => [
        dimension,
        this.average(
          evaluations.map((evaluation) => evaluation.dimensions[dimension]),
        ),
      ]),
    ) as unknown as InterviewDimensions;

    return {
      overallScore: this.average(
        evaluations.map((evaluation) => evaluation.overallScore),
      ),
      dimensions,
      strengths: this.uniqueItems(
        evaluations.flatMap((evaluation) => evaluation.strengths),
      ),
      improvements: this.uniqueItems(
        evaluations.flatMap((evaluation) => evaluation.improvements),
      ),
      answerCount: evaluations.length,
    };
  }

  private uniqueItems(items: string[]): string[] {
    return [...new Set(items)].slice(0, 5);
  }

  private average(values: number[]): number {
    return Math.round(
      values.reduce((total, value) => total + value, 0) / values.length,
    );
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

  private toQuestionResponse(question: InterviewTurn) {
    return {
      turnId: question.id,
      text: question.content,
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
