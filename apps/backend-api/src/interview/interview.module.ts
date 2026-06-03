import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { INTERVIEW_LLM_CLIENT } from './interview.constants';
import { InterviewController } from './interview.controller';
import { InterviewSpeechController } from './interview-speech.controller';
import { InterviewService } from './interview.service';
import { InterviewSessionRepository } from './repositories/interview-session.repository';
import {
  INTERVIEW_SPEECH_SYNTHESIS_CLIENT,
  INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT,
} from './speech/interview-speech.constants';
import { CompanyContextService } from './services/company-context.service';
import { ElevenLabsTtsService } from './services/elevenlabs-tts.service';
import { GroqSttService } from './services/groq-stt.service';
import { InterviewAudioValidator } from './services/interview-audio-validator.service';
import { GroqLlmService } from './services/groq-llm.service';
import { InterviewEvaluationValidator } from './services/interview-evaluation-validator.service';
import { InterviewInputValidator } from './services/interview-input-validator.service';
import { InterviewPromptService } from './services/interview-prompt.service';
import { InterviewSpeechService } from './services/interview-speech.service';
import { InterviewSummaryService } from './services/interview-summary.service';

@Module({
  imports: [SupabaseModule],
  controllers: [InterviewController, InterviewSpeechController],
  providers: [
    InterviewService,
    InterviewSpeechService,
    InterviewSessionRepository,
    CompanyContextService,
    InterviewInputValidator,
    InterviewAudioValidator,
    InterviewPromptService,
    InterviewSummaryService,
    InterviewEvaluationValidator,
    {
      provide: INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT,
      useClass: GroqSttService,
    },
    {
      provide: INTERVIEW_SPEECH_SYNTHESIS_CLIENT,
      useClass: ElevenLabsTtsService,
    },
    {
      provide: INTERVIEW_LLM_CLIENT,
      useClass: GroqLlmService,
    },
  ],
})
export class InterviewModule {}
