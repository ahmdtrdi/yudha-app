import { HttpException, Inject, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { SupabaseService } from '../supabase/supabase.service';
import { InterviewService } from './interview.service';
import { InterviewSessionRepository } from './repositories/interview-session.repository';
import {
  InterviewSpeechStreamError,
  InterviewSpeechStreamService,
} from './services/interview-speech-stream.service';
import {
  INTERVIEW_SPEECH_SYNTHESIS_CLIENT,
  INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT,
} from './speech/interview-speech.constants';
import type {
  InterviewSpeechSynthesisClient,
  InterviewSpeechTranscriptionClient,
} from './speech/interview-speech.types';
import { InterviewGuardrailService } from './services/interview-guardrail.service';

interface AuthenticatedSocket extends Socket {
  data: {
    userId?: string;
  };
}

interface LiveAudioChunkPayload {
  commandId: string;
  sessionId: string;
  answerId: string;
  sequence: number;
  audio: string;
  encoding: string;
  sampleRateHz: number;
  channels: number;
}

interface FinishAnswerPayload {
  commandId: string;
  sessionId: string;
  answerId: string;
  finalSequence: number;
}

@WebSocketGateway({
  namespace: '/interview-speech',
  cors: { origin: '*' },
})
export class InterviewSpeechGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(InterviewSpeechGateway.name);
  private readonly liveSpeechEnabled: boolean;
  private readonly devTokensEnabled: boolean;
  private readonly isProduction: boolean;

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly repository: InterviewSessionRepository,
    private readonly interviewService: InterviewService,
    private readonly speechStreamService: InterviewSpeechStreamService,
    private readonly guardrailService: InterviewGuardrailService,
    private readonly configService: ConfigService,
    @Inject(INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT)
    private readonly sttClient: InterviewSpeechTranscriptionClient,
    @Inject(INTERVIEW_SPEECH_SYNTHESIS_CLIENT)
    private readonly ttsClient: InterviewSpeechSynthesisClient,
  ) {
    this.liveSpeechEnabled = this.readBoolean(
      'INTERVIEW_LIVE_SPEECH_ENABLED',
      false,
    );
    this.devTokensEnabled = this.readBoolean(
      'ENABLE_INTERVIEW_DEV_TOKENS',
      false,
    );
    this.isProduction =
      this.configService.get<string>('NODE_ENV', 'development') ===
      'production';
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      if (!this.liveSpeechEnabled) {
        this.sendError(
          client,
          'FEATURE_DISABLED',
          'Live interview speech is disabled.',
          undefined,
          false,
        );
        client.disconnect(true);
        return;
      }

      const token = this.extractToken(client);
      if (!token) {
        client.disconnect(true);
        return;
      }

      if (
        !this.isProduction &&
        this.devTokensEnabled &&
        (token === 'dev-token' || token === 'dummy-token')
      ) {
        client.data.userId = '00000000-0000-0000-0000-000000000001';
        return;
      }

      const supabase = this.supabaseService.getClient();
      const { data, error } = await supabase.auth.getUser(token);
      if (error || !data?.user?.id) {
        client.disconnect(true);
        return;
      }

      client.data.userId = data.user.id;
    } catch (error) {
      this.logger.error(
        `Live speech authentication failed for socket ${client.id}.`,
        error,
      );
      client.disconnect(true);
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.speechStreamService.clearClient(client.id);
  }

  @SubscribeMessage('start_session')
  async handleStartSession(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: { commandId: string; sessionId: string },
  ) {
    try {
      const userId = this.assertUserId(client);
      const session = await this.repository.getOwnedSession(
        payload.sessionId,
        userId,
      );
      if (session.status !== 'active') {
        return this.sendError(
          client,
          'CONFLICT',
          'Interview session is not active.',
          payload,
          false,
        );
      }
      if (session.responseStyle !== 'voice') {
        return this.sendError(
          client,
          'CONFLICT',
          'Interview session is not configured for voice responses.',
          payload,
          false,
        );
      }

      this.speechStreamService.startSession(
        this.streamKey(client, payload.sessionId),
      );
      client.emit('session_ready', {
        commandId: payload.commandId,
        sessionId: payload.sessionId,
        status: 'ready',
        audioConfig: this.speechStreamService.getLimits(),
      });
    } catch (error) {
      this.handleError(client, error, payload);
    }
  }

  @SubscribeMessage('audio_chunk')
  handleAudioChunk(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: LiveAudioChunkPayload,
  ) {
    try {
      this.assertUserId(client);
      const accepted = this.speechStreamService.appendAudioChunk(
        this.streamKey(client, payload.sessionId),
        payload,
      );
      client.emit('audio_chunk_ack', {
        commandId: payload.commandId,
        sessionId: payload.sessionId,
        answerId: payload.answerId,
        sequence: accepted.sequence,
        totalBytes: accepted.totalBytes,
      });
    } catch (error) {
      this.handleError(client, error, payload);
    }
  }

  @SubscribeMessage('finish_answer')
  async handleFinishAnswer(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: FinishAnswerPayload,
  ) {
    const streamKey = this.streamKey(client, payload.sessionId);
    let prepareNextCapture = false;
    try {
      const userId = this.assertUserId(client);
      const session = await this.repository.getOwnedSession(
        payload.sessionId,
        userId,
      );
      if (session.status !== 'active') {
        return this.sendError(
          client,
          'CONFLICT',
          'Interview session is not active.',
          payload,
          false,
        );
      }

      const wavAudio = this.speechStreamService.finishAnswer(
        streamKey,
        payload.answerId,
        payload.finalSequence,
      );
      const transcription = await this.sttClient.transcribe({
        audio: wavAudio,
        fileName: 'answer.wav',
        mimeType: 'audio/wav',
        language: 'id',
        prompt: `${session.targetRole} di ${session.contextSnapshot.companyName}`,
      });

      const guardrailResult = this.guardrailService.validateAnswer(
        transcription.text,
      );
      if (!guardrailResult.isAllowed) {
        return this.sendError(
          client,
          'GUARDRAIL_VIOLATION',
          guardrailResult.reason ?? 'Jawaban tidak dapat diproses.',
          payload,
          true,
        );
      }

      client.emit('transcript_final', {
        commandId: payload.commandId,
        sessionId: payload.sessionId,
        answerId: payload.answerId,
        text: transcription.text,
      });

      const turnResult = await this.interviewService.submitAnswer(
        userId,
        payload.sessionId,
        {
          idempotencyKey: payload.answerId,
          answer: { type: 'text', text: transcription.text },
        },
      );

      if (turnResult.evaluation) {
        client.emit('evaluation', {
          commandId: payload.commandId,
          sessionId: payload.sessionId,
          answerId: payload.answerId,
          evaluation: turnResult.evaluation,
        });
      }

      if (turnResult.nextQuestion) {
        const question = turnResult.nextQuestion;
        client.emit('question_text', {
          commandId: payload.commandId,
          sessionId: payload.sessionId,
          answerId: payload.answerId,
          turnId: question.turnId,
          text: question.text,
        });

        try {
          const synthesis = await this.ttsClient.synthesize({
            text: question.text,
            language: 'id',
          });
          const chunks = this.speechStreamService.chunkTtsAudio(
            synthesis.audio,
          );
          client.emit('question_audio_start', {
            commandId: payload.commandId,
            sessionId: payload.sessionId,
            answerId: payload.answerId,
            turnId: question.turnId,
            contentType: synthesis.contentType,
            fileExtension: synthesis.fileExtension,
            provider: synthesis.provider,
            totalChunks: chunks.length,
          });
          for (const chunk of chunks) {
            client.emit('question_audio_chunk', {
              commandId: payload.commandId,
              sessionId: payload.sessionId,
              answerId: payload.answerId,
              turnId: question.turnId,
              sequence: chunk.sequence,
              audio: chunk.audio,
            });
          }
          client.emit('question_audio_end', {
            commandId: payload.commandId,
            sessionId: payload.sessionId,
            answerId: payload.answerId,
            turnId: question.turnId,
            finalSequence: chunks.length - 1,
          });
        } catch (error) {
          this.logger.warn(
            `Question speech synthesis failed for session ${payload.sessionId}.`,
          );
          this.sendError(
            client,
            'TTS_UNAVAILABLE',
            'Pertanyaan tersedia sebagai teks, tetapi audionya belum dapat diputar.',
            payload,
            true,
            { phase: 'question_audio' },
          );
        }

        client.emit('turn_completed', {
          commandId: payload.commandId,
          sessionId: payload.sessionId,
          answerId: payload.answerId,
          turnId: question.turnId,
          status: turnResult.status,
        });
        prepareNextCapture = turnResult.status === 'active';
      }

      if (turnResult.status === 'completed') {
        client.emit('session_completed', {
          commandId: payload.commandId,
          sessionId: payload.sessionId,
          answerId: payload.answerId,
          finalSummary: turnResult.finalSummary,
        });
      }
    } catch (error) {
      this.handleError(client, error, payload);
    } finally {
      if (prepareNextCapture) {
        this.speechStreamService.startSession(streamKey);
      } else {
        this.speechStreamService.clearSession(streamKey);
      }
    }
  }

  @SubscribeMessage('cancel')
  handleCancel(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody()
    payload: { commandId: string; sessionId: string; answerId?: string },
  ) {
    try {
      this.assertUserId(client);
      this.speechStreamService.resetSession(
        this.streamKey(client, payload.sessionId),
      );
      client.emit('cancelled', {
        commandId: payload.commandId,
        sessionId: payload.sessionId,
        answerId: payload.answerId,
        status: 'cancelled',
      });
    } catch (error) {
      this.handleError(client, error, payload);
    }
  }

  private streamKey(client: Socket, sessionId: string): string {
    return `${client.id}:${sessionId}`;
  }

  private extractToken(client: Socket): string | null {
    const authHeader =
      client.handshake.auth?.token ?? client.handshake.headers?.authorization;
    if (typeof authHeader !== 'string') {
      return null;
    }
    return authHeader.startsWith('Bearer ')
      ? authHeader.slice(7).trim()
      : authHeader.trim();
  }

  private assertUserId(client: AuthenticatedSocket): string {
    if (!client.data.userId) {
      throw new Error('Socket client is not authenticated.');
    }
    return client.data.userId;
  }

  private handleError(
    client: Socket,
    error: unknown,
    context?: { commandId?: string; sessionId?: string; answerId?: string },
  ): void {
    if (error instanceof InterviewSpeechStreamError) {
      this.sendError(client, error.code, error.message, context, true);
      return;
    }

    if (error instanceof HttpException) {
      const status = error.getStatus();
      if (status < 500) {
        const codeByStatus: Record<number, string> = {
          400: 'BAD_REQUEST',
          401: 'UNAUTHORIZED',
          403: 'FORBIDDEN',
          404: 'NOT_FOUND',
          409: 'CONFLICT',
        };
        this.sendError(
          client,
          codeByStatus[status] ?? 'REQUEST_REJECTED',
          error.message,
          context,
          status === 409,
        );
        return;
      }
      this.sendError(
        client,
        status === 504 ? 'PROVIDER_TIMEOUT' : 'PROVIDER_UNAVAILABLE',
        'Live interview speech is temporarily unavailable.',
        context,
        true,
      );
      return;
    }

    this.sendError(
      client,
      'PROVIDER_UNAVAILABLE',
      'Live interview speech is temporarily unavailable.',
      context,
      true,
    );
  }

  private sendError(
    client: Socket,
    code: string,
    message: string,
    context?: { commandId?: string; sessionId?: string; answerId?: string },
    recoverable = true,
    details: Record<string, unknown> = {},
  ): void {
    client.emit('error', {
      commandId: context?.commandId,
      sessionId: context?.sessionId,
      answerId: context?.answerId,
      error: {
        code,
        message,
        details: { recoverable, ...details },
      },
    });
  }

  private readBoolean(key: string, fallback: boolean): boolean {
    const raw = this.configService.get<string>(key);
    if (raw === undefined) {
      return fallback;
    }
    return raw.trim().toLowerCase() === 'true';
  }
}
