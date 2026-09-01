import { BadRequestException, Injectable } from '@nestjs/common';
import {
  parseSoloDraftSessionRequest,
  SoloContractValidationError,
} from './solo-contract';
import {
  CreateSoloSessionDto,
  FinishSoloSessionDto,
  OpenSoloQuestionDto,
  SubmitSoloAnswerDto,
} from './solo.dto';
import { SoloRepository } from './solo.repository';

@Injectable()
export class SoloService {
  constructor(private readonly repository: SoloRepository) {}

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
    if (
      selected != null &&
      (!Number.isInteger(selected) || selected < 0 || selected > 5)
    ) {
      throw new BadRequestException(
        'selectedOptionIndex must be null or an integer between 0 and 5.',
      );
    }
    return {
      data: await this.repository.submitAnswer({
        userId,
        sessionId: this.text(sessionId, 'sessionId'),
        idempotencyKey: this.text(input.idempotencyKey, 'idempotencyKey'),
        sessionQuestionId: this.text(
          input.sessionQuestionId,
          'sessionQuestionId',
        ),
        selectedOptionIndex: selected ?? null,
      }),
    };
  }

  async finishSession(
    userId: string,
    sessionId: string,
    input: FinishSoloSessionDto,
  ) {
    return {
      data: await this.repository.finishSession(
        userId,
        this.text(sessionId, 'sessionId'),
        this.text(input.idempotencyKey, 'idempotencyKey'),
      ),
    };
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
