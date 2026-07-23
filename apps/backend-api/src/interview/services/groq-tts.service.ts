import {
  GatewayTimeoutException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type {
  InterviewSpeechSynthesisClient,
  InterviewSpeechSynthesisInput,
  InterviewSpeechSynthesisResult,
} from '../speech/interview-speech.types';

@Injectable()
export class GroqTtsService implements InterviewSpeechSynthesisClient {
  private readonly logger = new Logger(GroqTtsService.name);
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly modelId: string;
  private readonly voiceId: string;
  private readonly timeoutMs: number;

  constructor(configService: ConfigService) {
    this.apiKey =
      configService.get<string>('GROQ_API_KEY') ??
      configService.get<string>('INTERVIEW_LLM_API_KEY') ??
      '';
    this.baseUrl = configService.get<string>(
      'INTERVIEW_GROQ_TTS_BASE_URL',
      'https://api.groq.com/openai/v1',
    );
    this.modelId = configService.get<string>(
      'INTERVIEW_GROQ_TTS_MODEL',
      'canopylabs/orpheus-v1-english',
    );
    this.voiceId = configService.get<string>(
      'INTERVIEW_GROQ_TTS_VOICE',
      'autumn',
    );
    this.timeoutMs = this.getPositiveInteger(
      configService,
      'INTERVIEW_GROQ_TTS_TIMEOUT_MS',
      15000,
    );
  }

  async synthesize(
    input: InterviewSpeechSynthesisInput,
  ): Promise<InterviewSpeechSynthesisResult> {
    if (!this.apiKey) {
      throw new ServiceUnavailableException(
        'Groq API key is missing for TTS synthesis.',
      );
    }

    try {
      const startedAt = Date.now();
      const response = await fetch(`${this.baseUrl}/audio/speech`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: this.modelId,
          input: input.text,
          voice: this.voiceId,
          response_format: 'wav',
        }),
        signal: AbortSignal.timeout(this.timeoutMs),
      });

      if (!response.ok) {
        const errorBody = await this.readErrorBody(response);
        this.logger.error(
          `Groq TTS request failed with status ${response.status}: ${errorBody}`,
        );

        if (errorBody.includes('model_terms_required') && this.modelId !== 'tts-1') {
          this.logger.warn(
            `⚠️ [Groq TTS] Terms acceptance required for model ${this.modelId}. Please accept terms at https://console.groq.com/playground?model=${encodeURIComponent(this.modelId)}. Retrying with fallback model 'tts-1'...`,
          );
          return this.synthesizeWithModel(input, 'tts-1', 'alloy');
        }

        throw new ServiceUnavailableException(
          'Groq speech synthesis is temporarily unavailable.',
        );
      }

      const latencyMs = Date.now() - startedAt;
      this.logger.log(
        `🔊 [TTS METRICS] Provider: Groq (${this.modelId}) | Latency: ${latencyMs}ms | Characters: ${input.text.length}`,
      );

      return {
        audio: Buffer.from(await response.arrayBuffer()),
        contentType: response.headers.get('content-type') ?? 'audio/wav',
        fileExtension: 'wav',
        provider: 'groq',
      };
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }

      if (error instanceof DOMException && error.name === 'TimeoutError') {
        throw new GatewayTimeoutException('Groq speech synthesis timed out.');
      }

      this.logger.error('Groq TTS request failed.', error);
      throw new ServiceUnavailableException(
        'Groq speech synthesis is temporarily unavailable.',
      );
    }
  }

  private async readErrorBody(response: Response): Promise<string> {
    try {
      return (await response.text()).slice(0, 1000);
    } catch {
      return 'Unable to read Groq TTS error response.';
    }
  }

  private async synthesizeWithModel(
    input: InterviewSpeechSynthesisInput,
    modelId: string,
    voiceId: string,
  ): Promise<InterviewSpeechSynthesisResult> {
    const startedAt = Date.now();
    const response = await fetch(`${this.baseUrl}/audio/speech`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: modelId,
        input: input.text,
        voice: voiceId,
        response_format: 'wav',
      }),
      signal: AbortSignal.timeout(this.timeoutMs),
    });

    if (!response.ok) {
      throw new ServiceUnavailableException('Groq fallback speech synthesis failed.');
    }

    const latencyMs = Date.now() - startedAt;
    this.logger.log(
      `🔊 [TTS METRICS] Provider: Groq (${modelId}) | Latency: ${latencyMs}ms | Characters: ${input.text.length}`,
    );

    return {
      audio: Buffer.from(await response.arrayBuffer()),
      contentType: response.headers.get('content-type') ?? 'audio/wav',
      fileExtension: 'wav',
      provider: 'groq',
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
