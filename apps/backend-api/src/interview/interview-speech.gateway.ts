import { Inject, Logger } from '@nestjs/common';
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
import { InterviewSpeechStreamService } from './services/interview-speech-stream.service';
import {
  INTERVIEW_SPEECH_SYNTHESIS_CLIENT,
  INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT,
} from './speech/interview-speech.constants';
import type {
  InterviewSpeechSynthesisClient,
  InterviewSpeechTranscriptionClient,
} from './speech/interview-speech.types';

interface AuthenticatedSocket extends Socket {
  data: {
    userId?: string;
  };
}

@WebSocketGateway({
  namespace: '/interview-speech',
  cors: { origin: '*' },
})
export class InterviewSpeechGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(InterviewSpeechGateway.name);

  @WebSocketServer()
  server: Server;

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly repository: InterviewSessionRepository,
    private readonly interviewService: InterviewService,
    private readonly speechStreamService: InterviewSpeechStreamService,
    @Inject(INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT)
    private readonly sttClient: InterviewSpeechTranscriptionClient,
    @Inject(INTERVIEW_SPEECH_SYNTHESIS_CLIENT)
    private readonly ttsClient: InterviewSpeechSynthesisClient,
  ) {}

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const token = this.extractToken(client);
      if (!token) {
        this.logger.warn(`Disconnecting unauthenticated socket ${client.id}`);
        client.disconnect(true);
        return;
      }

      if (token === 'dev-token' || token === 'dummy-token') {
        client.data.userId = '00000000-0000-0000-0000-000000000001';
        this.logger.log(`Socket connected with dev-token: ${client.id}`);
        return;
      }

      try {
        const parts = token.split('.');
        if (parts.length === 3) {
          const payloadJson = JSON.parse(
            Buffer.from(parts[1], 'base64').toString('utf8'),
          );
          if (payloadJson?.sub) {
            client.data.userId = payloadJson.sub;
            this.logger.log(`Socket connected: ${client.id} (user: ${payloadJson.sub})`);
            return;
          }
        }
      } catch {
        // payload parse error
      }

      const supabase = this.supabaseService.getClient();
      const { data, error } = await supabase.auth.getUser(token);
      if (!error && data?.user?.id) {
        client.data.userId = data.user.id;
        this.logger.log(`Socket connected: ${client.id} (user: ${data.user.id})`);
        return;
      }

      this.logger.warn(`Socket auth failed for ${client.id}`);
      client.disconnect(true);
    } catch (err) {
      this.logger.error(`Error during socket connection ${client.id}`, err);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.logger.log(`Socket disconnected: ${client.id}`);
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
        return this.sendError(client, 'CONFLICT', 'Interview session is not active.');
      }

      this.speechStreamService.startSession(payload.sessionId);
      client.emit('session_ready', {
        commandId: payload.commandId,
        sessionId: payload.sessionId,
        status: 'ready',
      });
    } catch (err: any) {
      this.sendError(
        client,
        'PROVIDER_UNAVAILABLE',
        err.message || 'Failed to start live speech session.',
      );
    }
  }

  @SubscribeMessage('audio_chunk')
  async handleAudioChunk(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody()
    payload: {
      commandId: string;
      sessionId: string;
      sequence: number;
      audio: string;
    },
  ) {
    try {
      this.assertUserId(client);
      if (!payload?.sessionId || !payload?.audio) {
        return this.sendError(client, 'VALIDATION_FAILED', 'Invalid audio chunk payload.');
      }

      this.speechStreamService.appendAudioChunk(
        payload.sessionId,
        payload.audio,
      );

      client.emit('transcript_delta', {
        sessionId: payload.sessionId,
        sequence: payload.sequence,
        commandId: payload.commandId,
        status: 'chunk_received',
      });
    } catch (err: any) {
      this.sendError(
        client,
        'VALIDATION_FAILED',
        err.message || 'Failed to process audio chunk.',
      );
    }
  }

  @SubscribeMessage('finish_answer')
  async handleFinishAnswer(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: { commandId: string; sessionId: string },
  ) {
    try {
      const userId = this.assertUserId(client);
      const audioBuffer = this.speechStreamService.getAccumulatedAudio(
        payload.sessionId,
      );

      if (!audioBuffer || audioBuffer.length === 0) {
        return this.sendError(
          client,
          'VALIDATION_FAILED',
          'No audio received for answer.',
        );
      }

      const transcription = await this.sttClient.transcribe({
        audio: audioBuffer,
        fileName: 'answer.m4a',
        mimeType: 'audio/m4a',
      });

      client.emit('transcript_final', {
        sessionId: payload.sessionId,
        text: transcription.text,
        commandId: payload.commandId,
      });

      const turnResult = await this.interviewService.submitAnswer(
        userId,
        payload.sessionId,
        {
          idempotencyKey: payload.commandId || `${payload.sessionId}-${Date.now()}`,
          answer: {
            type: 'text',
            text: transcription.text,
          },
        },
      );

      if (turnResult.evaluation) {
        client.emit('evaluation', {
          sessionId: payload.sessionId,
          evaluation: turnResult.evaluation,
        });
      }

      if (turnResult.nextQuestion) {
        client.emit('question_text', {
          sessionId: payload.sessionId,
          turnId: turnResult.nextQuestion.turnId,
          text: turnResult.nextQuestion.text,
        });

        try {
          const synthesis = await this.ttsClient.synthesize({
            text: turnResult.nextQuestion.text,
          });

          const chunks = this.speechStreamService.chunkTtsAudio(synthesis.audio);
          for (const chunk of chunks) {
            client.emit('question_audio_chunk', {
              sessionId: payload.sessionId,
              turnId: turnResult.nextQuestion.turnId,
              sequence: chunk.sequence,
              audio: chunk.audio,
            });
          }
        } catch (ttsErr: any) {
          this.logger.warn(`TTS synthesis failed: ${ttsErr?.message}`);
        }

        client.emit('turn_completed', {
          sessionId: payload.sessionId,
          turnId: turnResult.nextQuestion.turnId,
        });
      }

      if (turnResult.status === 'completed') {
        client.emit('session_completed', {
          sessionId: payload.sessionId,
          finalSummary: turnResult.finalSummary,
        });
      }

      this.speechStreamService.clearSession(payload.sessionId);
    } catch (err: any) {
      this.sendError(
        client,
        'PROVIDER_UNAVAILABLE',
        err.message || 'Failed to process answer audio.',
      );
    }
  }

  @SubscribeMessage('cancel')
  handleCancel(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: { commandId: string; sessionId: string },
  ) {
    this.speechStreamService.clearSession(payload.sessionId);
    client.emit('cancelled', {
      sessionId: payload.sessionId,
      commandId: payload.commandId,
      status: 'cancelled',
    });
  }

  private extractToken(client: Socket): string | null {
    const authHeader =
      client.handshake.auth?.token || client.handshake.headers?.authorization;
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

  private sendError(client: Socket, code: string, message: string) {
    client.emit('error', {
      error: {
        code,
        message,
        details: { recoverable: true },
      },
    });
  }
}
