import { BadRequestException, Injectable } from '@nestjs/common';
import { learningV2Enabled } from '../learning/learning.constants';
import { LearningProjectionService } from '../learning/learning.projection.service';
import type { LearningTarget } from '../learning/learning.types';
import {
  parseSoloDraftSessionRequest,
  SoloContractValidationError,
} from './solo-contract';
import {
  CreateSoloSessionDto,
  FinishSoloSessionDto,
  OpenSoloQuestionDto,
  RequestSoloHintDto,
  SubmitSoloAnswerDto,
} from './solo.dto';
import { SoloRepository } from './solo.repository';

@Injectable()
export class SoloService {
  constructor(
    private readonly repository: SoloRepository,
    private readonly learningProjections: LearningProjectionService,
  ) {}

  async createSession(userId: string, input: CreateSoloSessionDto) {
    let request;
    try {
      request = parseSoloDraftSessionRequest(input);
    } catch (error) {
      if (error instanceof SoloContractValidationError) {
        throw new BadRequestException(error.message);
      }
      throw error;
    }
    if (
      request.mechanicMode !== 'standard' ||
      request.questionSelection.type !== 'balanced'
    ) {
      throw new BadRequestException(
        'Commit 5 supports only Balanced + Standard sessions.',
      );
    }
    return {
      data: await this.repository.createSession({
        userId,
        idempotencyKey: request.idempotencyKey,
        mechanicMode: request.mechanicMode,
        questionSelection: request.questionSelection.type,
        questionCount: request.questionCount,
        characterId: request.characterId,
      }),
    };
  }

  async requestHint(
    userId: string,
    sessionId: string,
    sessionQuestionId: string,
    input: RequestSoloHintDto,
  ) {
    return {
      data: await this.repository.requestHint(
        userId,
        this.text(sessionId, 'sessionId'),
        this.text(sessionQuestionId, 'sessionQuestionId'),
        this.text(input.idempotencyKey, 'idempotencyKey'),
      ),
    };
  }

  async getSession(userId: string, sessionId: string) {
    return {
      data: await this.repository.getSession(
        userId,
        this.text(sessionId, 'sessionId'),
      ),
    };
  }

  async getActiveSession(userId: string) {
    return { data: await this.repository.getActiveSession(userId) };
  }

  async openQuestion(
    userId: string,
    sessionId: string,
    sessionQuestionId: string,
    input: OpenSoloQuestionDto,
  ) {
    return {
      data: await this.repository.openQuestion(
        userId,
        this.text(sessionId, 'sessionId'),
        this.text(sessionQuestionId, 'sessionQuestionId'),
        this.text(input.idempotencyKey, 'idempotencyKey'),
      ),
    };
  }

  async submitAnswer(
    userId: string,
    sessionId: string,
    input: SubmitSoloAnswerDto,
  ) {
    const selected = input.selectedOptionIndex;
    const activeMs = this.optionalNonNegativeInteger(
      input.clientActiveResponseTimeMs,
      'clientActiveResponseTimeMs',
    );
    const backgroundMs = this.optionalNonNegativeInteger(
      input.backgroundDurationMs,
      'backgroundDurationMs',
    );
    if (
      selected != null &&
      (!Number.isInteger(selected) || selected < 0 || selected > 5)
    ) {
      throw new BadRequestException(
        'selectedOptionIndex must be null or an integer between 0 and 5.',
      );
    }
    const data = await this.repository.submitAnswer({
      userId,
      sessionId: this.text(sessionId, 'sessionId'),
      idempotencyKey: this.text(input.idempotencyKey, 'idempotencyKey'),
      sessionQuestionId: this.text(
        input.sessionQuestionId,
        'sessionQuestionId',
      ),
      selectedOptionIndex: selected ?? null,
      clientActiveResponseTimeMs: activeMs,
      backgroundDurationMs: backgroundMs,
    });
    if (data.status === 'completed') {
      await this.rebuildLearning(userId, data.target);
    }
    return { data };
  }

  async finishSession(
    userId: string,
    sessionId: string,
    input: FinishSoloSessionDto,
  ) {
    const data = await this.repository.finishSession(
      userId,
      this.text(sessionId, 'sessionId'),
      this.text(input.idempotencyKey, 'idempotencyKey'),
    );
    await this.rebuildLearning(userId, data.target);
    return { data };
  }

  private async rebuildLearning(userId: string, target: unknown) {
    if (!learningV2Enabled() || (target !== 'cpns' && target !== 'bumn')) {
      return;
    }
    await this.learningProjections.rebuildAndDrainUser(
      userId,
      target as LearningTarget,
    );
  }

  private optionalNonNegativeInteger(
    value: unknown,
    field: string,
  ): number | null {
    if (value == null) return null;
    if (!Number.isInteger(value) || (value as number) < 0) {
      throw new BadRequestException(`${field} must be a non-negative integer.`);
    }
    return value as number;
  }

  private text(value: unknown, field: string): string {
    if (
      typeof value !== 'string' ||
      value.trim().length === 0 ||
      value.length > 160
    ) {
      throw new BadRequestException(`${field} must contain 1..160 characters.`);
    }
    return value.trim();
  }
}
