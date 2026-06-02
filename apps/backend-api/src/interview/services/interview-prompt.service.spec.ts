import { ConfigService } from '@nestjs/config';
import { InterviewLlmInput } from '../interview.types';
import { InterviewPromptService } from './interview-prompt.service';

describe('InterviewPromptService', () => {
  const service = new InterviewPromptService(
    new ConfigService({ INTERVIEW_PROMPT_VERSION: 'test-v1' }),
  );

  it('keeps realistic follow-up questions free from coaching language', () => {
    const messages = service.buildEvaluationMessages(createInput('realistic'));

    expect(messages[1].content).toContain('Evaluation is internal');
    expect(messages[1].content).toContain('Do not mention scores');
  });

  it('enables immediate educational feedback in coaching mode', () => {
    const messages = service.buildEvaluationMessages(createInput('coaching'));

    expect(messages[1].content).toContain('Coaching mode is active');
    expect(messages[1].content).toContain('shown immediately');
  });
});

function createInput(mode: string): InterviewLlmInput {
  return {
    companyContext: {
      companyId: 'test-company',
      companyName: 'Test Company',
      contentVersion: 'v1',
      briefing: 'Test briefing.',
    },
    targetRole: 'Management Trainee',
    mode,
    language: 'Bahasa Indonesia',
    rollingSummary: '',
    recentTurns: [],
    latestQuestion: 'Ceritakan tentang diri Anda.',
    latestAnswer: 'Saya memiliki pengalaman memimpin tim.',
  };
}
