import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { InterviewDimensions, InterviewEvaluation } from '../interview.types';

const dimensionNames: (keyof InterviewDimensions)[] = [
  'relevance',
  'clarity',
  'structure',
  'confidence',
  'impact',
  'authenticity',
];

@Injectable()
export class InterviewEvaluationValidator {
  parse(value: unknown): InterviewEvaluation {
    if (!this.isRecord(value)) {
      this.throwInvalidOutput();
    }

    const dimensions = value.dimensions;
    if (!this.isRecord(dimensions)) {
      this.throwInvalidOutput();
    }

    for (const dimension of dimensionNames) {
      if (!this.isScore(dimensions[dimension])) {
        this.throwInvalidOutput();
      }
    }

    if (
      !this.isScore(value.overallScore) ||
      !this.isCandidateFacts(value.candidateFacts) ||
      !this.isStringList(value.strengths) ||
      !this.isStringList(value.improvements) ||
      !this.isNonEmptyString(value.suggestedRewrite) ||
      !this.isNonEmptyString(value.nextQuestion) ||
      typeof value.shouldEndSession !== 'boolean' ||
      !this.isOptionalString(value.endReason) ||
      !this.isOptionalString(value.coachNote)
    ) {
      this.throwInvalidOutput();
    }

    return value as unknown as InterviewEvaluation;
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
  }

  private isScore(value: unknown): value is number {
    return (
      typeof value === 'number' &&
      Number.isInteger(value) &&
      value >= 0 &&
      value <= 100
    );
  }

  private isStringList(value: unknown): value is string[] {
    return (
      Array.isArray(value) &&
      value.length >= 1 &&
      value.length <= 5 &&
      value.every((item) => this.isNonEmptyString(item))
    );
  }

  private isCandidateFacts(value: unknown): value is string[] {
    return (
      Array.isArray(value) &&
      value.length <= 8 &&
      value.every((item) => this.isNonEmptyString(item))
    );
  }

  private isNonEmptyString(value: unknown): value is string {
    return typeof value === 'string' && value.trim().length > 0;
  }

  private isOptionalString(value: unknown): boolean {
    return value === undefined || value === null || typeof value === 'string';
  }

  private throwInvalidOutput(): never {
    throw new ServiceUnavailableException(
      'The interview model returned an invalid evaluation.',
    );
  }
}
