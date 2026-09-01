export type TargetType = 'cpns' | 'bumn';

export type QualityState = 'development' | 'approved' | 'under_review' | 'invalidated' | 'disabled';

export type CaseStatus = 'open' | 'in_review' | 'resolved' | 'dismissed';

export type CasePriority = 'low' | 'medium' | 'high' | 'critical';

export type CaseDisposition =
  | 'no_issue'
  | 'revise_content'
  | 'revise_answer_or_explanation'
  | 'remap_skill_or_difficulty'
  | 'invalidate_revision'
  | 'deactivate_question'
  | 'reactivate_question';

export interface DistractorStat {
  optionIndex: number;
  text: string;
  count: number;
  percentage: number;
  isCorrect: boolean;
}

export interface QuestionMetrics {
  totalAttempts: number;
  unseenAttempts: number;
  overallAccuracy: number; // 0 - 100
  unseenAccuracy: number; // 0 - 100
  seenUnseenGap: number; // percentage points
  medianResponseTimeMs: number;
  timeoutRate: number; // 0 - 100
  hintRate: number; // 0 - 100
  discriminationIndex: number; // -1.0 to 1.0
  distractors: DistractorStat[];
  signals: string[];
}

export interface QuestionItem {
  id: string;
  sourceKey: string;
  revision: number;
  target: TargetType;
  category: string;
  subcategory: string | null;
  primarySkillId: string;
  prerequisiteSkillIds: string[];
  prompt: string;
  options: string[];
  correctOptionIndex: number;
  explanation: string;
  difficulty: number; // 1 - 5
  standardTimeLimitMs: number;
  expectedTimeMs: number | null;
  curriculumWeight: number;
  assessmentEligible: boolean;
  qualityState: QualityState;
  smeApproved: boolean;
  approvedAt: string | null;
  approverReference: string | null;
  active: boolean;
  metrics: QuestionMetrics;
  lastUsedAt: string;
  deactivatedAt?: string | null;
  deactivationReason?: string | null;
  deactivatedBy?: string | null;
}

export interface ReviewCaseNote {
  id: string;
  author: string;
  authorRole: string;
  timestamp: string;
  content: string;
}

export interface ReviewCase {
  id: string;
  questionId: string;
  questionRevision: number;
  target: TargetType;
  category: string;
  skillId: string;
  promptSnippet: string;
  status: CaseStatus;
  priority: CasePriority;
  signals: string[];
  manualReason: string;
  evidenceSnapshot: {
    overallAccuracy: number;
    unseenAccuracy: number;
    timeoutRate: number;
    hintRate: number;
    medianResponseTimeMs: number;
    totalAttempts: number;
    flaggedDistractors?: number[];
  };
  assignedTo: string;
  notes: ReviewCaseNote[];
  disposition: CaseDisposition | null;
  createdAt: string;
  updatedAt: string;
  resolvedAt: string | null;
  resolvedBy: string | null;
}

export interface SkillCoverage {
  skillId: string;
  skillName: string;
  category: string;
  target: TargetType;
  activeCount: number;
  underReviewCount: number;
  disabledCount: number;
  minimumRequired: number;
  isBelowMinimum: boolean;
  difficultyDistribution: Record<number, number>; // 1: 5, 2: 10, etc.
}

export interface AuditLogEntry {
  id: string;
  timestamp: string;
  adminEmail: string;
  action: 'deactivate_question' | 'reactivate_question' | 'create_case' | 'update_case_status' | 'resolve_case' | 'invalidate_revision';
  targetResource: string;
  resourceId: string;
  reason: string;
  metadata?: Record<string, unknown>;
  idempotencyKey: string;
}

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: 'admin';
  token: string;
}
