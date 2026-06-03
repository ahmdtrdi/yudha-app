import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
} from '@nestjs/common';
import { InterviewSessionRepository } from '../repositories/interview-session.repository';
import {
  INTERVIEW_SPEECH_SYNTHESIS_CLIENT,
  INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT,
} from '../speech/interview-speech.constants';
import type {
  InterviewSpeechSynthesisClient,
  InterviewSpeechTranscriptionClient,
  UploadedAudioFile,
} from '../speech/interview-speech.types';
import { InterviewAudioValidator } from './interview-audio-validator.service';

@Injectable()
export class InterviewSpeechService {
  constructor(
    private readonly repository: InterviewSessionRepository,
    private readonly audioValidator: InterviewAudioValidator,
    @Inject(INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT)
    private readonly transcriptionClient: InterviewSpeechTranscriptionClient,
    @Inject(INTERVIEW_SPEECH_SYNTHESIS_CLIENT)
    private readonly synthesisClient: InterviewSpeechSynthesisClient,
  ) {}

  async transcribeAnswerAudio(
    userId: string,
    sessionId: string,
    file: UploadedAudioFile | undefined,
  ) {
    const session = await this.repository.getOwnedSession(sessionId, userId);

    if (session.status !== 'active') {
      throw new ConflictException('Interview session is not active.');
    }

    const audioFile = this.audioValidator.validateUploadedAudio(file);
    const transcription = await this.transcriptionClient.transcribe({
      audio: audioFile.buffer,
      fileName: audioFile.originalname || 'recording.webm',
      mimeType: audioFile.mimetype,
      language: session.language,
      prompt: await this.buildTranscriptionPrompt(session.id),
    });

    return {
      sessionId: session.id,
      responseStyle: session.responseStyle,
      transcript: transcription,
      answer: {
        type: 'text',
        text: transcription.text,
      },
    };
  }

  async synthesizeQuestionAudio(
    userId: string,
    sessionId: string,
    turnId: string,
  ) {
    const session = await this.repository.getOwnedSession(sessionId, userId);
    const turn = await this.repository.getSessionTurn(session.id, turnId);

    if (turn.role !== 'question') {
      throw new BadRequestException(
        'Only question turns can be synthesized to audio.',
      );
    }

    const audio = await this.synthesisClient.synthesize({
      text: turn.content,
      language: session.language,
    });

    return {
      ...audio,
      fileName: `interview-question-${turn.id}.${audio.fileExtension}`,
      turnId: turn.id,
      sessionId: session.id,
      text: turn.content,
    };
  }

  private async buildTranscriptionPrompt(sessionId: string): Promise<string> {
    const recentTurns = await this.repository.listRecentTurns(sessionId, 4);
    const latestQuestion = [...recentTurns]
      .reverse()
      .find((turn) => turn.role === 'question');

    return [
      'This audio is a candidate answer in a job interview.',
      'Preserve Indonesian spelling for company names, ministries, role titles, and education terms.',
      latestQuestion
        ? `Latest interviewer question: ${latestQuestion.content}`
        : null,
    ]
      .filter(Boolean)
      .join(' ');
  }
}
