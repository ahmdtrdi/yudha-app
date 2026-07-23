import {
  GatewayTimeoutException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type {
  InterviewSpeechTranscription,
  InterviewSpeechTranscriptionClient,
  InterviewSpeechTranscriptionInput,
} from '../speech/interview-speech.types';

interface GroqTranscriptionResponse {
  text?: string;
  language?: string;
  duration?: number;
}

@Injectable()
export class GroqSttService implements InterviewSpeechTranscriptionClient {
  private readonly logger = new Logger(GroqSttService.name);
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly model: string;
  private readonly timeoutMs: number;

  constructor(configService: ConfigService) {
    this.apiKey =
      configService.get<string>('INTERVIEW_STT_API_KEY') ??
      configService.get<string>('GROQ_API_KEY') ??
      this.requireConfig(configService, 'INTERVIEW_LLM_API_KEY');
    this.baseUrl = configService.get<string>(
      'INTERVIEW_STT_BASE_URL',
      'https://api.groq.com/openai/v1',
    );
    this.model = configService.get<string>(
      'INTERVIEW_STT_MODEL',
      'whisper-large-v3-turbo',
    );
    this.timeoutMs = this.getPositiveInteger(
      configService,
      'INTERVIEW_STT_TIMEOUT_MS',
      15000,
    );
  }

  async transcribe(
    input: InterviewSpeechTranscriptionInput,
  ): Promise<InterviewSpeechTranscription> {
    try {
      const audioBytes = input.audio.buffer.slice(
        input.audio.byteOffset,
        input.audio.byteOffset + input.audio.byteLength,
      ) as ArrayBuffer;
      const formData = new FormData();
      const resolvedMime =
        !input.mimeType || input.mimeType === 'application/octet-stream'
          ? input.fileName?.endsWith('.m4a')
            ? 'audio/m4a'
            : input.fileName?.endsWith('.mp3')
              ? 'audio/mp3'
              : input.fileName?.endsWith('.wav')
                ? 'audio/wav'
                : 'audio/m4a'
          : input.mimeType;

      formData.append(
        'file',
        new File([audioBytes], input.fileName || 'recording.m4a', {
          type: resolvedMime,
        }),
      );
      formData.append('model', this.model);
      formData.append('response_format', 'verbose_json');

      if (input.language) {
        formData.append('language', input.language);
      }

      if (input.prompt) {
        formData.append('prompt', input.prompt.slice(0, 500));
      }

      const startedAt = Date.now();
      const response = await fetch(`${this.baseUrl}/audio/transcriptions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: formData,
        signal: AbortSignal.timeout(this.timeoutMs),
      });

      if (!response.ok) {
        const errorBody = await this.readErrorBody(response);
        this.logger.error(
          `Groq STT request failed with status ${response.status}: ${errorBody}`,
        );
        throw new ServiceUnavailableException(
          'Speech transcription is temporarily unavailable.',
        );
      }

      const payload = (await response.json()) as
        | GroqTranscriptionResponse
        | undefined;
      const text = payload?.text?.trim();

      if (!text) {
        throw new ServiceUnavailableException(
          'Speech transcription returned empty text.',
        );
      }

      const latencyMs = Date.now() - startedAt;
      this.logger.log(
        `🎙️ [STT METRICS] Provider: Groq (${this.model}) | Latency: ${latencyMs}ms | Duration: ${payload?.duration ?? 'unknown'}s`,
      );

      return {
        text,
        language: payload?.language ?? null,
        durationSeconds:
          typeof payload?.duration === 'number' ? payload.duration : null,
        provider: 'groq',
      };
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }

      if (error instanceof DOMException && error.name === 'TimeoutError') {
        throw new GatewayTimeoutException('Speech transcription timed out.');
      }

      this.logger.error('Groq STT request failed.', error);
      throw new ServiceUnavailableException(
        'Speech transcription is temporarily unavailable.',
      );
    }
  }

  private async readErrorBody(response: Response): Promise<string> {
    try {
      return (await response.text()).slice(0, 1000);
    } catch {
      return 'Unable to read Groq STT error response.';
    }
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
}
