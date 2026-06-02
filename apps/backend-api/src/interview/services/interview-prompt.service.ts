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
      'You are conducting a job interview for a candidate.',
      `Prompt version: ${this.promptVersion}.`,
      `Respond in ${language}.`,
      'Evaluate the latest answer using the provided rubric.',
      'Be specific, constructive, and grounded in the company briefing.',
      'Never invent company facts that are absent from the briefing.',
      'Ask one concise follow-up question.',
      'Extract explicit candidate facts such as name, education status, field of study, experience, interests, or target role. Never infer missing facts.',
      'Use candidate facts from the answer and session summary to acknowledge the candidate naturally before asking the next question when appropriate.',
      'For the first follow-up after the candidate introduces themself, start nextQuestion with a short acknowledgment of their current status or field of study when provided, then ask a broad question about motivation or relevant experience.',
      'Keep the first interview turns broad and conversational: identity, education or current status, motivation, and relevant experience.',
      'Ask one topic at a time. Do not jump into deep operational or technical questions before the candidate has provided enough background.',
      'Use company context lightly and naturally. Do not force company-specific facts into every question.',
      'Use integer scores from 0 to 100.',
      'Rubric dimensions: relevance, clarity, structure, confidence, impact, authenticity.',
      'Return every required response field: overallScore, dimensions, candidateFacts, strengths, improvements, suggestedRewrite, nextQuestion, shouldEndSession, endReason, coachNote.',
      'Use null for endReason or coachNote when there is no applicable value.',
      'Set shouldEndSession to true only when the answer indicates the session should stop.',
    ].join('\n');
  }

  private buildCompanyBriefing(input: InterviewLlmInput): string {
    return [
      `Company: ${input.companyContext.companyName}`,
      `Target role: ${input.targetRole}`,
      `Interview mode: ${input.mode}`,
      this.buildModeInstruction(input.mode),
      'Company briefing:',
      input.companyContext.briefing,
    ].join('\n');
  }

  private buildModeInstruction(mode: string): string {
    if (mode === 'coaching') {
      return [
        'Coaching mode is active.',
        'Feedback will be shown immediately, so make it actionable and educational.',
      ].join(' ');
    }

    return [
      'Realistic interview mode is active.',
      'Evaluation is internal until the session ends.',
      'The next question must sound like a natural interviewer response.',
      'Do not mention scores, rubric dimensions, strengths, improvements, or coaching advice in the next question.',
    ].join(' ');
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
