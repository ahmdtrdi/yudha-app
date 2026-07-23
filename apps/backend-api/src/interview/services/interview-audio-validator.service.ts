import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UploadedAudioFile } from '../speech/interview-speech.types';

const supportedAudioMimeTypes = new Set([
  'audio/mpeg',
  'audio/mp3',
  'audio/mp4',
  'audio/x-m4a',
  'audio/m4a',
  'audio/wav',
  'audio/x-wav',
  'audio/webm',
  'audio/ogg',
  'audio/aac',
  'application/octet-stream',
]);

const supportedAudioExtensions = new Set([
  '.mp3',
  '.m4a',
  '.wav',
  '.mp4',
  '.webm',
  '.ogg',
  '.aac',
]);

@Injectable()
export class InterviewAudioValidator {
  private readonly maxBytes: number;

  constructor(configService: ConfigService) {
    this.maxBytes = this.getPositiveInteger(
      configService,
      'INTERVIEW_AUDIO_MAX_BYTES',
      10 * 1024 * 1024,
    );
  }

  validateUploadedAudio(
    file: UploadedAudioFile | undefined,
  ): UploadedAudioFile {
    if (!file || !file.buffer || file.size <= 0) {
      throw new BadRequestException('audio file is required.');
    }

    if (file.size > this.maxBytes) {
      throw new BadRequestException(
        `audio file must not exceed ${this.maxBytes} bytes.`,
      );
    }

    const fileExtension = (file.originalname || '').toLowerCase().slice((file.originalname || '').lastIndexOf('.'));
    const isSupportedMime = supportedAudioMimeTypes.has(file.mimetype);
    const isSupportedExtension = supportedAudioExtensions.has(fileExtension);

    if (!isSupportedMime && !isSupportedExtension) {
      throw new BadRequestException(
        `audio mime type ${file.mimetype} is not supported.`,
      );
    }

    return file;
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
