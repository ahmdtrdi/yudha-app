import { Logger } from '@nestjs/common';
import type {
  InterviewEvaluation,
  InterviewLlmClient,
  InterviewLlmInput,
} from '../interview.types';

export class FallbackLlmService implements InterviewLlmClient {
  private readonly logger = new Logger(FallbackLlmService.name);

  constructor(
    private readonly primary: InterviewLlmClient,
    private readonly fallback: InterviewLlmClient,
    private readonly primaryName: string,
    private readonly fallbackName: string,
  ) {}

  async evaluateAnswer(input: InterviewLlmInput): Promise<InterviewEvaluation> {
    try {
      return await this.primary.evaluateAnswer(input);
    } catch (primaryError) {
      this.logger.warn(
        `⚠️ [${this.primaryName.toUpperCase()} FAILED] ${primaryError instanceof Error ? primaryError.message : primaryError}. Falling back to ${this.fallbackName}...`,
      );

      try {
        return await this.fallback.evaluateAnswer(input);
      } catch (fallbackError) {
        this.logger.error(
          `❌ [${this.fallbackName.toUpperCase()} ALSO FAILED] ${fallbackError instanceof Error ? fallbackError.message : fallbackError}`,
        );
        throw fallbackError;
      }
    }
  }
}
