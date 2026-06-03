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
export class ElevenLabsTtsService implements InterviewSpeechSynthesisClient {
  private readonly logger = new Logger(ElevenLabsTtsService.name);
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly voiceId: string;
  private readonly modelId: string;
  private readonly outputFormat: string;
  private readonly timeoutMs: number;

  constructor(configService: ConfigService) {
    this.apiKey = this.requireConfig(configService, 'ELEVENLABS_API_KEY');
    this.baseUrl = configService.get<string>(
      'INTERVIEW_TTS_BASE_URL',
      'https://api.elevenlabs.io/v1',
    );
    this.voiceId = this.requireConfig(configService, 'INTERVIEW_TTS_VOICE_ID');
    this.modelId = configService.get<string>(
      'INTERVIEW_TTS_MODEL_ID',
      'eleven_flash_v2_5',
    );
    this.outputFormat = configService.get<string>(
      'INTERVIEW_TTS_OUTPUT_FORMAT',
      'mp3_44100_128',
    );
    this.timeoutMs = this.getPositiveInteger(
      configService,
      'INTERVIEW_TTS_TIMEOUT_MS',
      15000,
    );
  }

  async synthesize(
    input: InterviewSpeechSynthesisInput,
  ): Promise<InterviewSpeechSynthesisResult> {
    try {
      const response = await fetch(
        `${this.baseUrl}/text-to-speech/${this.voiceId}?output_format=${this.outputFormat}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'xi-api-key': this.apiKey,
          },
          body: JSON.stringify({
            text: input.text,
            model_id: this.modelId,
            language_code: input.language,
          }),
          signal: AbortSignal.timeout(this.timeoutMs),
        },
      );

      if (!response.ok) {
        const errorBody = await this.readErrorBody(response);
        this.logger.error(
          `ElevenLabs TTS request failed with status ${response.status}: ${errorBody}`,
        );
        throw new ServiceUnavailableException(
          'Speech synthesis is temporarily unavailable.',
        );
      }

      return {
        audio: Buffer.from(await response.arrayBuffer()),
        contentType: response.headers.get('content-type') ?? 'audio/mpeg',
        fileExtension: this.resolveFileExtension(),
        provider: 'elevenlabs',
      };
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }

      if (error instanceof DOMException && error.name === 'TimeoutError') {
        throw new GatewayTimeoutException('Speech synthesis timed out.');
      }

      this.logger.error('ElevenLabs TTS request failed.', error);
      throw new ServiceUnavailableException(
        'Speech synthesis is temporarily unavailable.',
      );
    }
  }

  private resolveFileExtension(): string {
    if (this.outputFormat.startsWith('wav')) {
      return 'wav';
    }

    if (this.outputFormat.startsWith('pcm')) {
      return 'pcm';
    }

    return 'mp3';
  }

  private async readErrorBody(response: Response): Promise<string> {
    try {
      return (await response.text()).slice(0, 1000);
    } catch {
      return 'Unable to read ElevenLabs error response.';
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
