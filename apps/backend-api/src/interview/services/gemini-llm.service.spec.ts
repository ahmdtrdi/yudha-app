import { ConfigService } from '@nestjs/config';
import { GeminiLlmService } from './gemini-llm.service';
import { InterviewEvaluationValidator } from './interview-evaluation-validator.service';
import { InterviewPromptService } from './interview-prompt.service';

describe('GeminiLlmService', () => {
  let service: GeminiLlmService;

  beforeEach(() => {
    const configService = new ConfigService({
      GEMINI_API_KEY: 'test-gemini-key',
      INTERVIEW_GEMINI_MODEL: 'gemini-3.1-flash',
    });
    const promptService = new InterviewPromptService(configService);
    const evaluationValidator = new InterviewEvaluationValidator();

    service = new GeminiLlmService(
      configService,
      promptService,
      evaluationValidator,
    );
  });

  it('instantiates cleanly with valid config', () => {
    expect(service).toBeDefined();
  });
});
