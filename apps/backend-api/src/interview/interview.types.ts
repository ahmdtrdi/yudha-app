export type InterviewSessionStatus = 'active' | 'completed' | 'failed';
export type InterviewTurnRole = 'question' | 'answer';
export type InterviewTurnProcessingStatus =
  | 'pending'
  | 'completed'
  | 'failed'
  | null;

export interface InterviewDimensions {
  relevance: number;
  clarity: number;
  structure: number;
  confidence: number;
  impact: number;
  authenticity: number;
}

export interface InterviewEvaluation {
  overallScore: number;
  dimensions: InterviewDimensions;
  strengths: string[];
  improvements: string[];
  suggestedRewrite: string;
  nextQuestion: string;
  shouldEndSession: boolean;
  endReason?: string | null;
  coachNote?: string | null;
}

export interface CompanyContextSnapshot {
  companyId: string;
  companyName: string;
  contentVersion: string;
  briefing: string;
}

export interface InterviewSession {
  id: string;
  userId: string;
  companyId: string;
  targetRole: string;
  mode: string;
  language: string;
  responseStyle: string;
  status: InterviewSessionStatus;
  contextSnapshot: CompanyContextSnapshot;
  rollingSummary: string;
  finalSummary: InterviewFinalSummary | null;
  createdAt: string;
  updatedAt: string;
}

export interface InterviewTurn {
  id: string;
  sessionId: string;
  role: InterviewTurnRole;
  content: string;
  idempotencyKey: string | null;
  parentTurnId: string | null;
  processingStatus: InterviewTurnProcessingStatus;
  evaluation: InterviewEvaluation | null;
  createdAt: string;
}

export interface InterviewFinalSummary {
  overallScore: number;
  dimensions: InterviewDimensions;
  strengths: string[];
  improvements: string[];
  answerCount: number;
}

export interface InterviewLlmInput {
  companyContext: CompanyContextSnapshot;
  targetRole: string;
  mode: string;
  language: string;
  rollingSummary: string;
  recentTurns: InterviewTurn[];
  latestQuestion: string;
  latestAnswer: string;
}

export interface InterviewLlmClient {
  evaluateAnswer(input: InterviewLlmInput): Promise<InterviewEvaluation>;
}
