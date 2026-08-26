import { Injectable, Logger } from '@nestjs/common';

interface SessionAudioState {
  chunks: Buffer[];
  totalSize: number;
  sequence: number;
}

@Injectable()
export class InterviewSpeechStreamService {
  private readonly logger = new Logger(InterviewSpeechStreamService.name);
  private readonly sessions = new Map<string, SessionAudioState>();

  startSession(sessionId: string): void {
    this.sessions.set(sessionId, {
      chunks: [],
      totalSize: 0,
      sequence: 0,
    });
  }

  appendAudioChunk(
    sessionId: string,
    audioData: string | Buffer,
  ): { sequence: number; totalChunks: number } {
    let state = this.sessions.get(sessionId);
    if (!state) {
      this.startSession(sessionId);
      state = this.sessions.get(sessionId)!;
    }

    const chunkBuffer =
      typeof audioData === 'string'
        ? Buffer.from(audioData, 'base64')
        : audioData;

    state.chunks.push(chunkBuffer);
    state.totalSize += chunkBuffer.length;
    state.sequence += 1;

    return {
      sequence: state.sequence - 1,
      totalChunks: state.chunks.length,
    };
  }

  getAccumulatedAudio(sessionId: string): Buffer | null {
    const state = this.sessions.get(sessionId);
    if (!state || state.chunks.length === 0) {
      return null;
    }

    return Buffer.concat(state.chunks);
  }

  chunkTtsAudio(
    audioBuffer: Buffer,
    chunkSizeBytes = 16384,
  ): Array<{ sequence: number; audio: string }> {
    const result: Array<{ sequence: number; audio: string }> = [];
    let offset = 0;
    let sequence = 0;

    while (offset < audioBuffer.length) {
      const end = Math.min(offset + chunkSizeBytes, audioBuffer.length);
      const chunk = audioBuffer.subarray(offset, end);
      result.push({
        sequence: sequence++,
        audio: chunk.toString('base64'),
      });
      offset = end;
    }

    return result;
  }

  clearSession(sessionId: string): void {
    this.sessions.delete(sessionId);
  }
}
