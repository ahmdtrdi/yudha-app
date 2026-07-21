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

const wordToNumberMap: Record<string, number> = {
  zero: 0,
  ten: 10,
  twenty: 20,
  thirty: 30,
  forty: 40,
  fifty: 50,
  sixty: 60,
  seventy: 70,
  eighty: 80,
  ninety: 90,
  hundred: 100,
};

@Injectable()
export class InterviewEvaluationValidator {
  parse(value: unknown): InterviewEvaluation {
    if (!this.isRecord(value)) {
      this.throwInvalidOutput('root is not an object');
    }

    // Coerce overallScore if it came back as string/word number
    value.overallScore = this.coerceScore(value.overallScore);

    const dimensions = value.dimensions;
    if (!this.isRecord(dimensions)) {
      this.throwInvalidOutput('dimensions is not an object');
    }

    for (const dimension of dimensionNames) {
      dimensions[dimension] = this.coerceScore(dimensions[dimension]);
      if (!this.isScore(dimensions[dimension])) {
        this.throwInvalidOutput(`dimensions.${dimension} is not a valid score: ${JSON.stringify(dimensions[dimension])}`);
      }
    }

    if (!this.isScore(value.overallScore)) {
      this.throwInvalidOutput(`overallScore is not a valid score: ${JSON.stringify(value.overallScore)}`);
    }

    // Coerce candidateFacts: Groq json_object mode may return it as an object instead of string[]
    value.candidateFacts = this.coerceCandidateFacts(value.candidateFacts);

    if (!this.isCandidateFacts(value.candidateFacts)) {
      this.throwInvalidOutput(`candidateFacts invalid: ${JSON.stringify(value.candidateFacts)}`);
    }
    if (!this.isStringList(value.strengths)) {
      this.throwInvalidOutput(`strengths invalid: ${JSON.stringify(value.strengths)}`);
    }
    if (!this.isStringList(value.improvements)) {
      this.throwInvalidOutput(`improvements invalid: ${JSON.stringify(value.improvements)}`);
    }
    if (!this.isNonEmptyString(value.suggestedRewrite)) {
      this.throwInvalidOutput(`suggestedRewrite invalid: ${JSON.stringify(value.suggestedRewrite)}`);
    }
    if (!this.isNonEmptyString(value.nextQuestion)) {
      this.throwInvalidOutput(`nextQuestion invalid: ${JSON.stringify(value.nextQuestion)}`);
    }
    if (typeof value.shouldEndSession !== 'boolean') {
      this.throwInvalidOutput(`shouldEndSession is not boolean: ${JSON.stringify(value.shouldEndSession)}`);
    }
    if (!this.isOptionalString(value.endReason)) {
      this.throwInvalidOutput(`endReason invalid: ${JSON.stringify(value.endReason)}`);
    }
    if (!this.isOptionalString(value.coachNote)) {
      this.throwInvalidOutput(`coachNote invalid: ${JSON.stringify(value.coachNote)}`);
    }

    return value as unknown as InterviewEvaluation;
  }

  private coerceScore(val: unknown): unknown {
    if (typeof val === 'number') {
      return Math.round(val);
    }

    if (typeof val === 'string') {
      const clean = val.trim().toLowerCase();
      const num = Number(clean);
      if (Number.isFinite(num)) {
        return Math.round(num);
      }

      if (wordToNumberMap[clean] !== undefined) {
        return wordToNumberMap[clean];
      }
    }

    return val;
  }

  /**
   * Coerce candidateFacts from object format to string[] format.
   * Groq json_object mode may return: {"name":"Tri","university":"Sam Ratulangi"}
   * We convert to: ["name: Tri", "university: Sam Ratulangi"]
   */
  private coerceCandidateFacts(val: unknown): unknown {
    if (Array.isArray(val)) {
      return val;
    }

    if (typeof val === 'object' && val !== null && !Array.isArray(val)) {
      return Object.entries(val as Record<string, unknown>)
        .filter(([, v]) => v !== null && v !== undefined && String(v).trim() !== '')
        .map(([key, v]) => `${key}: ${String(v)}`);
    }

    return val;
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

  private throwInvalidOutput(context?: string): never {
    throw new ServiceUnavailableException(
      `The interview model returned an invalid evaluation.${context ? ` (${context})` : ''}`,
    );
  }
}
