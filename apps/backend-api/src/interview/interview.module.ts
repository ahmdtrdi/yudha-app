import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { INTERVIEW_LLM_CLIENT } from './interview.constants';
import { InterviewController } from './interview.controller';
import { InterviewService } from './interview.service';
import { InterviewSessionRepository } from './repositories/interview-session.repository';
import { CompanyContextService } from './services/company-context.service';
import { GroqLlmService } from './services/groq-llm.service';
import { InterviewEvaluationValidator } from './services/interview-evaluation-validator.service';
import { InterviewInputValidator } from './services/interview-input-validator.service';
import { InterviewPromptService } from './services/interview-prompt.service';
import { InterviewSummaryService } from './services/interview-summary.service';

@Module({
  imports: [SupabaseModule],
  controllers: [InterviewController],
  providers: [
    InterviewService,
    InterviewSessionRepository,
    CompanyContextService,
    InterviewInputValidator,
    InterviewPromptService,
    InterviewSummaryService,
    InterviewEvaluationValidator,
    {
      provide: INTERVIEW_LLM_CLIENT,
      useClass: GroqLlmService,
    },
  ],
})
export class InterviewModule {}
