import {
  GatewayTimeoutException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { INTERVIEW_EVALUATION_SCHEMA } from '../interview.constants';
import {
  InterviewEvaluation,
  InterviewLlmClient,
  InterviewLlmInput,
} from '../interview.types';
import { InterviewEvaluationValidator } from './interview-evaluation-validator.service';
import { InterviewPromptService } from './interview-prompt.service';

interface GroqChatCompletion {
  choices?: Array<{
    message?: {
      content?: string;
    };
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
  };
}

@Injectable()
export class GroqLlmService implements InterviewLlmClient {
  private readonly logger = new Logger(GroqLlmService.name);
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly model: string;
  private readonly timeoutMs: number;
  private readonly maxOutputTokens: number;
  private readonly maxRetries: number;
  private readonly reasoningEffort: string;

  constructor(
    configService: ConfigService,
    private readonly promptService: InterviewPromptService,
    private readonly evaluationValidator: InterviewEvaluationValidator,
  ) {
    this.apiKey =
      configService.get<string>('GROQ_API_KEY') ??
      this.requireConfig(configService, 'INTERVIEW_LLM_API_KEY');
    this.baseUrl = configService.get<string>(
      'INTERVIEW_LLM_BASE_URL',
      'https://api.groq.com/openai/v1',
    );
    this.model = configService.get<string>(
      'INTERVIEW_LLM_MODEL',
      'openai/gpt-oss-120b',
    );
    this.timeoutMs = this.getPositiveInteger(
      configService,
      'INTERVIEW_LLM_TIMEOUT_MS',
      15000,
    );
    this.maxOutputTokens = this.getPositiveInteger(
      configService,
      'INTERVIEW_LLM_MAX_OUTPUT_TOKENS',
      2048,
    );
    this.maxRetries = this.getNonNegativeInteger(
      configService,
      'INTERVIEW_LLM_MAX_RETRIES',
      1,
    );
    this.reasoningEffort = configService.get<string>(
      'INTERVIEW_LLM_REASONING_EFFORT',
      'low',
    );
  }

  async evaluateAnswer(input: InterviewLlmInput): Promise<InterviewEvaluation> {
    const startedAt = Date.now();

    try {
      const response = await this.requestCompletion(input);

      const completion = (await response.json()) as GroqChatCompletion;
      const content = completion.choices?.[0]?.message?.content;

      if (!content) {
        throw new ServiceUnavailableException(
          'The interview model returned an empty response.',
        );
      }

      this.logUsage(completion, startedAt);

      return this.evaluationValidator.parse(JSON.parse(content) as unknown);
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }

      if (error instanceof DOMException && error.name === 'TimeoutError') {
        throw new GatewayTimeoutException('The interview model timed out.');
      }

      this.logger.error('Groq request failed.', error);
      throw new ServiceUnavailableException(
        'The interview model is temporarily unavailable.',
      );
    }
  }

  private async requestCompletion(input: InterviewLlmInput): Promise<Response> {
    for (let attempt = 0; attempt <= this.maxRetries; attempt += 1) {
      const response = await fetch(`${this.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: this.model,
          messages: this.promptService.buildEvaluationMessages(input),
          max_completion_tokens: this.maxOutputTokens,
          reasoning_effort: this.reasoningEffort,
          response_format: {
            type: 'json_schema',
            json_schema: {
              name: 'interview_evaluation',
              strict: true,
              schema: INTERVIEW_EVALUATION_SCHEMA,
            },
          },
        }),
        signal: AbortSignal.timeout(this.timeoutMs),
      });

      if (response.ok) {
        return response;
      }

      const errorBody = await this.readErrorBody(response);
      const canRetry =
        attempt < this.maxRetries &&
        (response.status === 429 ||
          response.status >= 500 ||
          errorBody.includes('"code":"json_validate_failed"'));

      if (!canRetry) {
        this.logger.error(
          `Groq request failed with status ${response.status}: ${errorBody}`,
        );
        throw new ServiceUnavailableException(
          'The interview model is temporarily unavailable.',
        );
      }

      await this.sleep(this.getRetryDelayMs(response, attempt));
    }

    throw new ServiceUnavailableException(
      'The interview model is temporarily unavailable.',
    );
  }

  private async readErrorBody(response: Response): Promise<string> {
    try {
      return (await response.text()).slice(0, 1000);
    } catch {
      return 'Unable to read Groq error response.';
    }
  }

  private getRetryDelayMs(response: Response, attempt: number): number {
    const retryAfterSeconds = Number(response.headers.get('retry-after'));
    if (Number.isFinite(retryAfterSeconds) && retryAfterSeconds >= 0) {
      return Math.min(retryAfterSeconds * 1000, 1500);
    }

    return Math.min(250 * 2 ** attempt + Math.random() * 100, 1500);
  }

  private async sleep(delayMs: number): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }

  private logUsage(completion: GroqChatCompletion, startedAt: number): void {
    const usage = completion.usage;
    this.logger.log(
      [
        `Groq completion model=${this.model}`,
        `latencyMs=${Date.now() - startedAt}`,
        `promptTokens=${usage?.prompt_tokens ?? 'unknown'}`,
        `completionTokens=${usage?.completion_tokens ?? 'unknown'}`,
        `totalTokens=${usage?.total_tokens ?? 'unknown'}`,
      ].join(' '),
    );
  }

  private requireConfig(configService: ConfigService, key: string): string {
    const value = configService.get<string>(key);
    if (!value) {
      throw new Error(`${key} is missing.`);
    }

    return value;
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

  private getNonNegativeInteger(
    configService: ConfigService,
    key: string,
    fallback: number,
  ): number {
    const value = Number(configService.get<string>(key, String(fallback)));
    if (!Number.isInteger(value) || value < 0) {
      throw new Error(`${key} must be a non-negative integer.`);
    }

    return value;
  }
}
