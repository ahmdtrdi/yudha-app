import { BadRequestException, Injectable } from '@nestjs/common';
import { StartInterviewSessionDto } from '../dto/start-interview-session.dto';
import { SubmitInterviewTurnDto } from '../dto/submit-interview-turn.dto';

@Injectable()
export class InterviewInputValidator {
  validateStartSession(input: StartInterviewSessionDto): void {
    this.requireText(input.companyId, 'companyId', 100);
    this.requireText(input.targetRole, 'targetRole', 120);
    this.requireText(input.mode, 'mode', 60);

    if (input.language !== undefined) {
      this.requireText(input.language, 'language', 10);
    }

    if (
      input.responseStyle !== undefined &&
      !['text', 'voice'].includes(input.responseStyle)
    ) {
      throw new BadRequestException(
        'responseStyle must be either text or voice.',
      );
    }
  }

  validateSubmitTurn(input: SubmitInterviewTurnDto): void {
    this.requireText(input.idempotencyKey, 'idempotencyKey', 120);

    if (!input.answer || input.answer.type !== 'text') {
      throw new BadRequestException('Only text answers are supported.');
    }

    this.requireText(input.answer.text, 'answer.text', 5000);
  }

  private requireText(value: unknown, field: string, maxLength: number): void {
    if (typeof value !== 'string' || value.trim().length === 0) {
      throw new BadRequestException(`${field} must be a non-empty string.`);
    }

    if (value.length > maxLength) {
      throw new BadRequestException(
        `${field} must not exceed ${maxLength} characters.`,
      );
    }
  }
}
