import {
  Controller,
  Get,
  Param,
  Post,
  Res,
  StreamableFile,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { InterviewSpeechService } from './services/interview-speech.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('interview/sessions')
@UseGuards(SupabaseAuthGuard)
export class InterviewSpeechController {
  constructor(
    private readonly interviewSpeechService: InterviewSpeechService,
  ) {}

  @Post(':sessionId/speech/transcriptions')
  @UseInterceptors(FileInterceptor('audio'))
  transcribeAnswerAudio(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @UploadedFile()
    file?: {
      buffer: Buffer;
      mimetype: string;
      originalname: string;
      size: number;
    },
  ) {
    return this.interviewSpeechService.transcribeAnswerAudio(
      user.id,
      sessionId,
      file,
    );
  }

  @Get(':sessionId/speech/questions/:turnId/audio')
  async synthesizeQuestionAudio(
    @GetUser() user: AuthenticatedUser,
    @Param('sessionId') sessionId: string,
    @Param('turnId') turnId: string,
    @Res({ passthrough: true }) response: Response,
  ) {
    const audio = await this.interviewSpeechService.synthesizeQuestionAudio(
      user.id,
      sessionId,
      turnId,
    );

    response.setHeader('Content-Type', audio.contentType);
    response.setHeader(
      'Content-Disposition',
      `inline; filename="${audio.fileName}"`,
    );
    response.setHeader('X-Interview-Speech-Provider', audio.provider);

    return new StreamableFile(audio.audio);
  }
}
