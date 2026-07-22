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
      'You are conducting a professional, warm, and natural job interview for an Indonesian enterprise or ministry.',
      `Prompt version: ${this.promptVersion}.`,
      `Respond in natural, fluent ${language}.`,
      'Evaluate the candidate answer using the provided rubric.',
      'Be specific, constructive, encouraging, and grounded in the company briefing.',
      'Never invent company facts that are absent from the briefing.',
      'Ask ONE natural, conversational follow-up question per turn.',
      'If the candidate gives a short answer (e.g. "mahasiswa", "fresh graduate", "jurusan akuntansi"), acknowledge it politely and warmly (e.g. "Salam kenal! Senang sekali Anda dari latar belakang mahasiswa..."), then ask a broad follow-up question about their field of study, relevant projects, or motivation.',
      'Extract explicit candidate facts such as name, education status, field of study, experience, interests, or target role. Never infer missing facts.',
      'Use candidate facts naturally in follow-up questions to sound like an empathetic human interviewer.',
      'Keep the tone respectful, professional, and engaging.',
      'Use integer scores from 0 to 100.',
      'CRITICAL: overallScore and all dimension scores MUST be raw numeric integers between 0 and 100 (e.g., 30, 45, 75). NEVER write scores as word strings like "thirty" or in quotes.',
      'Rubric dimensions: relevance, clarity, structure, confidence, impact, authenticity.',
      'Return every required response field: overallScore, dimensions, candidateFacts, strengths, improvements, suggestedRewrite, nextQuestion, shouldEndSession, endReason, coachNote.',
      'Use null for endReason or coachNote when there is no applicable value.',
      'Set shouldEndSession to true only when the candidate requests to stop or maximum turns are reached.',
      'Respond with a valid JSON object containing all required fields.',
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
