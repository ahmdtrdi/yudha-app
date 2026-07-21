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

interface NativeGeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string }>;
    };
    finishReason?: string;
  }>;
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    totalTokenCount?: number;
  };
  error?: {
    code?: number;
    message?: string;
    status?: string;
  };
}

@Injectable()
export class GeminiLlmService implements InterviewLlmClient {
  private readonly logger = new Logger(GeminiLlmService.name);
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly configuredModel: string;
  private readonly fallbackModels: string[];
  private readonly geminiSchema: Record<string, unknown>;
  private readonly timeoutMs: number;
  private readonly maxOutputTokens: number;
  private readonly maxRetries: number;

  constructor(
    configService: ConfigService,
    private readonly promptService: InterviewPromptService,
    private readonly evaluationValidator: InterviewEvaluationValidator,
  ) {
    this.apiKey =
      configService.get<string>('GEMINI_API_KEY') ??
      configService.get<string>('INTERVIEW_GEMINI_API_KEY') ??
      this.requireConfig(configService, 'INTERVIEW_LLM_API_KEY');

    let baseUrl = configService.get<string>(
      'INTERVIEW_GEMINI_BASE_URL',
      'https://generativelanguage.googleapis.com/v1beta',
    );
    if (baseUrl.endsWith('/openai')) {
      this.logger.warn(
        'INTERVIEW_GEMINI_BASE_URL ends with /openai — stripping it for native Gemini API compatibility.',
      );
      baseUrl = baseUrl.replace(/\/openai$/, '');
    }
    this.baseUrl = baseUrl;

    this.configuredModel = configService.get<string>(
      'INTERVIEW_GEMINI_MODEL',
      'gemini-3.5-flash',
    );
    this.fallbackModels = (configService.get<string>('INTERVIEW_GEMINI_FALLBACK_MODELS', '') ?? '')
      .split(',')
      .map((m) => m.trim())
      .filter(Boolean);
    this.timeoutMs = this.getPositiveInteger(
      configService,
      'INTERVIEW_GEMINI_TIMEOUT_MS',
      25000,
    );
    this.maxOutputTokens = this.getPositiveInteger(
      configService,
      'INTERVIEW_GEMINI_MAX_OUTPUT_TOKENS',
      2048,
    );
    this.maxRetries = this.getNonNegativeInteger(
      configService,
      'INTERVIEW_GEMINI_MAX_RETRIES',
      2,
    );

    if (!this.apiKey.startsWith('AIzaSy') && !this.apiKey.startsWith('AQ.')) {
      this.logger.warn(
        `⚠️ GEMINI_API_KEY format tidak dikenali (awalan: '${this.apiKey.slice(0, 6)}...'). Format yang valid: 'AIzaSy...' (legacy) atau 'AQ...' (new Auth Key).`,
      );
    }

    this.geminiSchema = this.toGeminiSchema(INTERVIEW_EVALUATION_SCHEMA);
  }

  async evaluateAnswer(input: InterviewLlmInput): Promise<InterviewEvaluation> {
    const startedAt = Date.now();

    try {
      const { data, usedModel } = await this.requestCompletion(input);

      const content = data.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!content) {
        throw new ServiceUnavailableException(
          'The Gemini interview model returned an empty response.',
        );
      }

      const parsedEvaluation = this.evaluationValidator.parse(
        JSON.parse(content) as unknown,
      );

      const latencyMs = Date.now() - startedAt;
      const promptTokens = data.usageMetadata?.promptTokenCount ?? 0;
      const completionTokens = data.usageMetadata?.candidatesTokenCount ?? 0;
      const totalTokens =
        data.usageMetadata?.totalTokenCount ?? promptTokens + completionTokens;

      this.logger.log(
        `📊 [AI METRICS] Provider: Gemini (${usedModel}) | Latency: ${latencyMs}ms | Tokens -> Prompt: ${promptTokens}, Output: ${completionTokens}, Total: ${totalTokens}`,
      );

      return Object.assign(parsedEvaluation, {
        _metrics: {
          provider: 'gemini',
          model: usedModel,
          latencyMs,
          promptTokens,
          completionTokens,
          totalTokens,
        },
      });
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }

      if (error instanceof DOMException && error.name === 'TimeoutError') {
        throw new GatewayTimeoutException('The Gemini interview model timed out.');
      }

      this.logger.error('Gemini request failed.', error);
      throw new ServiceUnavailableException(
        'The Gemini interview model is temporarily unavailable.',
      );
    }
  }

  private async requestCompletion(
    input: InterviewLlmInput,
  ): Promise<{ data: NativeGeminiResponse; usedModel: string }> {
    const modelsToTry = Array.from(
      new Set([this.configuredModel, ...this.fallbackModels]),
    );

    const messages = this.promptService.buildEvaluationMessages(input);
    const systemPrompt = messages
      .filter((m) => m.role === 'system')
      .map((m) => m.content)
      .join('\n\n');
    const userPrompt = messages
      .filter((m) => m.role === 'user')
      .map((m) => m.content)
      .join('\n\n');

    const requestBody = {
      systemInstruction: {
        parts: [{ text: systemPrompt }],
      },
      contents: [
        {
          role: 'user',
          parts: [{ text: userPrompt }],
        },
      ],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: this.maxOutputTokens,
        responseMimeType: 'application/json',
        responseSchema: this.geminiSchema,
      },
    };

    let lastError: string = '';

    for (const currentModel of modelsToTry) {
      const cleanModelName = currentModel.replace(/^models\//, '');
      const apiUrl = `${this.baseUrl}/models/${cleanModelName}:generateContent`;

      for (let attempt = 0; attempt <= this.maxRetries; attempt += 1) {
        try {
          const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': this.apiKey,
            },
            body: JSON.stringify(requestBody),
            signal: AbortSignal.timeout(this.timeoutMs),
          });

          const rawText = await response.text();
          let data: NativeGeminiResponse | undefined;

          try {
            data = JSON.parse(rawText) as NativeGeminiResponse;
          } catch {
            data = undefined;
          }

          if (response.ok && data?.candidates?.[0]?.content?.parts?.[0]?.text) {
            return { data, usedModel: cleanModelName };
          }

          const errorMsg =
            data?.error?.message || rawText || `HTTP ${response.status}`;
          lastError = errorMsg;

          if (
            response.status === 404 ||
            errorMsg.includes('not found') ||
            errorMsg.includes('API key not valid') ||
            errorMsg.includes('no longer available')
          ) {
            this.logger.warn(
              `Gemini model ${cleanModelName} error: ${errorMsg}. Trying next available model/fallback...`,
            );
            break;
          }

          const canRetry =
            attempt < this.maxRetries &&
            (response.status === 429 || response.status >= 500);

          if (!canRetry) {
            this.logger.error(
              `Gemini request failed (${cleanModelName}) status ${response.status}: ${errorMsg}`,
            );
            break;
          }

          const delayMs = this.getRetryDelayMs(response, attempt, errorMsg);
          this.logger.warn(
            `Gemini rate limit (${response.status}). Retrying attempt ${
              attempt + 1
            }/${this.maxRetries} after ${delayMs}ms...`,
          );
          await this.sleep(delayMs);
        } catch (err) {
          this.logger.warn(`Gemini attempt error (${cleanModelName}): ${err}`);
        }
      }
    }

    throw new ServiceUnavailableException(
      `Gemini model unavailable: ${lastError || 'Check API key or quota.'}`,
    );
  }

  private getRetryDelayMs(
    response: Response,
    attempt: number,
    errorBody?: string,
  ): number {
    if (errorBody) {
      const match = errorBody.match(/Please retry in ([\d\.]+)s/i);
      if (match && match[1]) {
        const parsedSeconds = Math.ceil(parseFloat(match[1]));
        if (parsedSeconds > 0 && parsedSeconds <= 20) {
          return parsedSeconds * 1000;
        }
      }
    }

    const retryAfterSeconds = Number(response.headers.get('retry-after'));
    if (Number.isFinite(retryAfterSeconds) && retryAfterSeconds >= 0) {
      return Math.min(retryAfterSeconds * 1000, 10000);
    }

    return Math.min(1000 * 2 ** attempt + Math.random() * 200, 5000);
  }

  private async sleep(delayMs: number): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, delayMs));
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

  /**
   * Converts an OpenAI-style JSON Schema to Gemini native responseSchema format.
   * Gemini uses uppercase type names and doesn't support additionalProperties,
   * minLength, minItems, maxItems. Nullable is expressed via `nullable: true`.
   */
  private toGeminiSchema(schema: Record<string, unknown>): Record<string, unknown> {
    const typeMap: Record<string, string> = {
      string: 'STRING',
      integer: 'INTEGER',
      number: 'NUMBER',
      boolean: 'BOOLEAN',
      array: 'ARRAY',
      object: 'OBJECT',
    };

    const convert = (node: unknown): Record<string, unknown> => {
      if (typeof node !== 'object' || node === null) {
        return {};
      }

      const src = node as Record<string, unknown>;
      const result: Record<string, unknown> = {};

      // Handle nullable type arrays like ['string', 'null']
      if (Array.isArray(src.type)) {
        const nonNullTypes = src.type.filter((t: string) => t !== 'null');
        if (nonNullTypes.length === 1) {
          result.type = typeMap[nonNullTypes[0]] ?? nonNullTypes[0];
          result.nullable = true;
        } else {
          result.type = typeMap[String(src.type)] ?? String(src.type);
        }
      } else if (typeof src.type === 'string') {
        result.type = typeMap[src.type] ?? src.type;
      }

      if (src.description) {
        result.description = src.description;
      }

      if (Array.isArray(src.required)) {
        result.required = src.required;
      }

      if (typeof src.properties === 'object' && src.properties !== null) {
        const props: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(src.properties as Record<string, unknown>)) {
          props[key] = convert(value);
        }
        result.properties = props;
      }

      if (typeof src.items === 'object' && src.items !== null) {
        result.items = convert(src.items);
      }

      // Gemini supports enum
      if (Array.isArray(src.enum)) {
        result.enum = src.enum;
      }

      // Skip unsupported fields: additionalProperties, minLength, minItems, maxItems, minimum, maximum

      return result;
    };

    return convert(schema);
  }
}
