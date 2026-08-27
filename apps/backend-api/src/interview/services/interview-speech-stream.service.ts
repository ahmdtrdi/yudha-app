import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type InterviewSpeechStreamErrorCode =
  | 'SESSION_NOT_READY'
  | 'ANSWER_CONFLICT'
  | 'INVALID_AUDIO_FORMAT'
  | 'INVALID_SEQUENCE'
  | 'CHUNK_TOO_LARGE'
  | 'ANSWER_TOO_LARGE'
  | 'ANSWER_TOO_LONG'
  | 'CAPTURE_TIMEOUT'
  | 'NO_AUDIO';

export class InterviewSpeechStreamError extends Error {
  constructor(
    readonly code: InterviewSpeechStreamErrorCode,
    message: string,
  ) {
    super(message);
  }
}

export interface LiveSpeechLimits {
  encoding: 'pcm_s16le';
  sampleRateHz: 16000;
  channels: 1;
  maxChunkBytes: number;
  maxAnswerBytes: number;
  maxAnswerSeconds: number;
  inactivityTimeoutMs: number;
}

interface SessionAudioState {
  answerId: string | null;
  chunks: Buffer[];
  totalSize: number;
  nextSequence: number;
  lastActivityAt: number;
}

interface AppendAudioChunkInput {
  answerId: string;
  sequence: number;
  audio: string | Buffer;
  encoding: string;
  sampleRateHz: number;
  channels: number;
}

@Injectable()
export class InterviewSpeechStreamService {
  private readonly sessions = new Map<string, SessionAudioState>();
  private readonly limits: LiveSpeechLimits;

  constructor(configService?: ConfigService) {
    this.limits = {
      encoding: 'pcm_s16le',
      sampleRateHz: 16000,
      channels: 1,
      maxChunkBytes: this.readPositiveInteger(
        configService,
        'INTERVIEW_LIVE_MAX_CHUNK_BYTES',
        64 * 1024,
      ),
      maxAnswerBytes: this.readPositiveInteger(
        configService,
        'INTERVIEW_AUDIO_MAX_BYTES',
        10 * 1024 * 1024,
      ),
      maxAnswerSeconds: this.readPositiveInteger(
        configService,
        'INTERVIEW_LIVE_MAX_ANSWER_SECONDS',
        90,
      ),
      inactivityTimeoutMs: this.readPositiveInteger(
        configService,
        'INTERVIEW_LIVE_INACTIVITY_TIMEOUT_MS',
        15_000,
      ),
    };
  }

  getLimits(): LiveSpeechLimits {
    return { ...this.limits };
  }

  startSession(streamKey: string): void {
    this.sessions.set(streamKey, {
      answerId: null,
      chunks: [],
      totalSize: 0,
      nextSequence: 0,
      lastActivityAt: Date.now(),
    });
  }

  appendAudioChunk(
    streamKey: string,
    input: AppendAudioChunkInput,
  ): { sequence: number; totalChunks: number; totalBytes: number } {
    const state = this.requireState(streamKey);
    this.assertNotInactive(state);
    this.assertFormat(input);
    this.assertAnswer(state, input.answerId);

    if (
      !Number.isInteger(input.sequence) ||
      input.sequence !== state.nextSequence
    ) {
      throw new InterviewSpeechStreamError(
        'INVALID_SEQUENCE',
        `Expected audio sequence ${state.nextSequence}.`,
      );
    }

    const chunk = this.decodeAudio(input.audio);
    if (chunk.length === 0) {
      throw new InterviewSpeechStreamError('NO_AUDIO', 'Audio chunk is empty.');
    }
    if (chunk.length > this.limits.maxChunkBytes) {
      throw new InterviewSpeechStreamError(
        'CHUNK_TOO_LARGE',
        `Audio chunk exceeds ${this.limits.maxChunkBytes} bytes.`,
      );
    }

    const nextTotal = state.totalSize + chunk.length;
    if (nextTotal > this.limits.maxAnswerBytes) {
      throw new InterviewSpeechStreamError(
        'ANSWER_TOO_LARGE',
        `Answer audio exceeds ${this.limits.maxAnswerBytes} bytes.`,
      );
    }

    const audioSeconds =
      nextTotal / (this.limits.sampleRateHz * this.limits.channels * 2);
    if (audioSeconds > this.limits.maxAnswerSeconds) {
      throw new InterviewSpeechStreamError(
        'ANSWER_TOO_LONG',
        `Answer audio exceeds ${this.limits.maxAnswerSeconds} seconds.`,
      );
    }

    state.chunks.push(chunk);
    state.totalSize = nextTotal;
    state.nextSequence += 1;
    state.lastActivityAt = Date.now();

    return {
      sequence: input.sequence,
      totalChunks: state.chunks.length,
      totalBytes: state.totalSize,
    };
  }

  finishAnswer(
    streamKey: string,
    answerId: string,
    finalSequence: number,
  ): Buffer {
    const state = this.requireState(streamKey);
    this.assertNotInactive(state);
    this.assertAnswer(state, answerId);

    const expectedFinalSequence = state.nextSequence - 1;
    if (
      !Number.isInteger(finalSequence) ||
      finalSequence !== expectedFinalSequence
    ) {
      throw new InterviewSpeechStreamError(
        'INVALID_SEQUENCE',
        `Expected final sequence ${expectedFinalSequence}.`,
      );
    }
    if (state.chunks.length === 0) {
      throw new InterviewSpeechStreamError(
        'NO_AUDIO',
        'No audio received for answer.',
      );
    }

    state.lastActivityAt = Date.now();
    return this.wrapPcm16AsWav(Buffer.concat(state.chunks));
  }

  wrapPcm16AsWav(pcm: Buffer): Buffer {
    const header = Buffer.alloc(44);
    const blockAlign = this.limits.channels * 2;
    const byteRate = this.limits.sampleRateHz * blockAlign;

    header.write('RIFF', 0);
    header.writeUInt32LE(36 + pcm.length, 4);
    header.write('WAVE', 8);
    header.write('fmt ', 12);
    header.writeUInt32LE(16, 16);
    header.writeUInt16LE(1, 20);
    header.writeUInt16LE(this.limits.channels, 22);
    header.writeUInt32LE(this.limits.sampleRateHz, 24);
    header.writeUInt32LE(byteRate, 28);
    header.writeUInt16LE(blockAlign, 32);
    header.writeUInt16LE(16, 34);
    header.write('data', 36);
    header.writeUInt32LE(pcm.length, 40);

    return Buffer.concat([header, pcm]);
  }

  chunkTtsAudio(
    audioBuffer: Buffer,
    chunkSizeBytes = 16_384,
  ): Array<{ sequence: number; audio: string }> {
    const result: Array<{ sequence: number; audio: string }> = [];
    for (
      let offset = 0, sequence = 0;
      offset < audioBuffer.length;
      offset += chunkSizeBytes, sequence += 1
    ) {
      result.push({
        sequence,
        audio: audioBuffer
          .subarray(
            offset,
            Math.min(offset + chunkSizeBytes, audioBuffer.length),
          )
          .toString('base64'),
      });
    }
    return result;
  }

  clearSession(streamKey: string): void {
    this.sessions.delete(streamKey);
  }

  resetSession(streamKey: string): boolean {
    if (!this.sessions.has(streamKey)) {
      return false;
    }
    this.startSession(streamKey);
    return true;
  }

  clearClient(clientId: string): void {
    const prefix = `${clientId}:`;
    for (const key of this.sessions.keys()) {
      if (key.startsWith(prefix)) {
        this.sessions.delete(key);
      }
    }
  }

  private requireState(streamKey: string): SessionAudioState {
    const state = this.sessions.get(streamKey);
    if (!state) {
      throw new InterviewSpeechStreamError(
        'SESSION_NOT_READY',
        'Live speech session is not ready.',
      );
    }
    return state;
  }

  private assertNotInactive(state: SessionAudioState): void {
    // Question playback can legitimately take longer than the transport timeout.
    // Start enforcing inactivity only after the first candidate audio chunk.
    if (state.nextSequence === 0) {
      return;
    }
    if (Date.now() - state.lastActivityAt > this.limits.inactivityTimeoutMs) {
      throw new InterviewSpeechStreamError(
        'CAPTURE_TIMEOUT',
        'Live speech capture timed out.',
      );
    }
  }

  private assertFormat(input: AppendAudioChunkInput): void {
    if (
      input.encoding !== this.limits.encoding ||
      input.sampleRateHz !== this.limits.sampleRateHz ||
      input.channels !== this.limits.channels
    ) {
      throw new InterviewSpeechStreamError(
        'INVALID_AUDIO_FORMAT',
        'Live speech requires 16 kHz mono PCM16 audio.',
      );
    }
  }

  private assertAnswer(state: SessionAudioState, answerId: string): void {
    if (!answerId?.trim()) {
      throw new InterviewSpeechStreamError(
        'ANSWER_CONFLICT',
        'answerId is required.',
      );
    }
    if (state.answerId === null) {
      state.answerId = answerId;
      return;
    }
    if (state.answerId !== answerId) {
      throw new InterviewSpeechStreamError(
        'ANSWER_CONFLICT',
        'Another answer is already being captured.',
      );
    }
  }

  private decodeAudio(audio: string | Buffer): Buffer {
    if (Buffer.isBuffer(audio)) {
      return audio;
    }
    if (
      typeof audio !== 'string' ||
      audio.length === 0 ||
      audio.length % 4 !== 0 ||
      !/^[A-Za-z0-9+/]*={0,2}$/.test(audio)
    ) {
      throw new InterviewSpeechStreamError(
        'INVALID_AUDIO_FORMAT',
        'Audio chunk must be valid base64.',
      );
    }
    return Buffer.from(audio, 'base64');
  }

  private readPositiveInteger(
    configService: ConfigService | undefined,
    key: string,
    fallback: number,
  ): number {
    const value = Number(
      configService?.get<string>(key, String(fallback)) ?? fallback,
    );
    if (!Number.isInteger(value) || value <= 0) {
      throw new Error(`${key} must be a positive integer.`);
    }
    return value;
  }
}
