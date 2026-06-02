import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InterviewLlmInput } from '../interview.types';

export interface InterviewPromptMessage {
  role: 'system' | 'user';
  content: string;
}

@Injectable()
export class InterviewPromptService {
  private readonly promptVersion: string;

  constructor(configService: ConfigService) {
    this.promptVersion = configService.get<string>(
      'INTERVIEW_PROMPT_VERSION',
      'interview-v1',
    );
  }

  buildEvaluationMessages(input: InterviewLlmInput): InterviewPromptMessage[] {
    return [
      {
        role: 'system',
        content: this.buildSystemInstruction(input.language),
      },
      {
        role: 'system',
        content: this.buildCompanyBriefing(input),
      },
      {
        role: 'user',
        content: this.buildLatestAnswerContext(input),
      },
    ];
  }

  private buildSystemInstruction(language: string): string {
    return [
      'You are an interview coach for job candidates.',
      `Prompt version: ${this.promptVersion}.`,
      `Respond in ${language}.`,
      'Evaluate the latest answer using the provided rubric.',
      'Be specific, constructive, and grounded in the company briefing.',
      'Never invent company facts that are absent from the briefing.',
      'Ask one concise follow-up question.',
      'Use integer scores from 0 to 100.',
      'Rubric dimensions: relevance, clarity, structure, confidence, impact, authenticity.',
      'Set shouldEndSession to true only when the answer indicates the session should stop.',
    ].join('\n');
  }

  private buildCompanyBriefing(input: InterviewLlmInput): string {
    return [
      `Company: ${input.companyContext.companyName}`,
      `Target role: ${input.targetRole}`,
      `Interview mode: ${input.mode}`,
      'Company briefing:',
      input.companyContext.briefing,
    ].join('\n');
  }

  private buildLatestAnswerContext(input: InterviewLlmInput): string {
    return [
      'Session summary:',
      input.rollingSummary || 'No prior answer summary.',
      '',
      'Recent transcript:',
      this.formatRecentTurns(input),
      '',
      `Latest question: ${input.latestQuestion}`,
      `Candidate answer: ${input.latestAnswer}`,
    ].join('\n');
  }

  private formatRecentTurns(input: InterviewLlmInput): string {
    if (input.recentTurns.length === 0) {
      return 'No prior turns.';
    }

    return input.recentTurns
      .map((turn) => `${turn.role}: ${turn.content}`)
      .join('\n');
  }
}
