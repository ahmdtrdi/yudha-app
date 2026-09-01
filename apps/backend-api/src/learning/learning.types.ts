export type LearningTarget = 'cpns' | 'bumn';
export type LearningSource = 'solo' | 'pvp' | 'assessment';
export type LearningMechanic = 'focus' | 'standard' | 'speed';
export type EvidenceConfidence = 'low' | 'medium' | 'high';
export type SoloSkillStatus =
  | 'collecting_data'
  | 'needs_repair'
  | 'developing'
  | 'needs_review'
  | 'needs_fluency'
  | 'secure';
export type LearningObjective =
  | 'repair_accuracy'
  | 'spaced_review'
  | 'collect_evidence'
  | 'build_fluency'
  | 'maintain_coverage';

export interface LearningAttemptEvidence {
  id: string;
  source: LearningSource;
  userId: string;
  target: LearningTarget;
  questionId: string | null;
  questionRevisionId: string | null;
  taxonomyVersionId: string | null;
  skillId: string | null;
  difficulty: string | null;
  requestedMechanicMode: LearningMechanic | null;
  effectiveMechanicMode: LearningMechanic | null;
  selectedOptionIndex: number | null;
  isCorrect: boolean | null;
  hintRequested: boolean | null;
  timedOut: boolean | null;
  firstAttempt: boolean | null;
  seenBefore: boolean | null;
  expectedTimeMs: number | null;
  standardTimeLimitMs: number | null;
  clientActiveResponseTimeMs: number | null;
  serverElapsedTimeMs: number | null;
  backgroundDurationMs: number | null;
  effectiveResponseTimeMs: number | null;
  timingInvalidityReason: string | null;
  sourceEventAt: string;
}

export interface ClassificationContext {
  ownershipValid?: boolean;
  sessionLegitimate?: boolean;
  sourceDuplicated?: boolean;
  revisionInvalidated?: boolean;
  retentionEligible?: boolean;
}

export interface EvidenceClassification {
  classificationVersion: string;
  validForActivityAccuracy: boolean;
  validForIndependentAccuracy: boolean;
  validForUnseenIndependentAccuracy: boolean;
  validForAssistedAccuracy: boolean;
  validForPaceAnalytics: boolean;
  validForFluencyBaseline: boolean;
  validForRetention: boolean;
  effectiveResponseTimeMs: number | null;
  exclusionReasons: string[];
}

export interface ClassifiedAttempt {
  attempt: LearningAttemptEvidence;
  classification: EvidenceClassification;
  invalidated?: boolean;
}

export interface RetentionStateInput {
  strongEvidenceAt: string | null;
  reviewDueAt: string | null;
  reviewDue: boolean;
  retentionCorrectCount: number;
  retentionAttemptCount: number;
  retentionAccuracy: number | null;
}

export interface SkillStateProjection {
  status: SoloSkillStatus;
  activityCorrectCount: number;
  activityAttemptCount: number;
  activityAccuracy: number | null;
  independentCorrectCount: number;
  independentAttemptCount: number;
  independentAccuracy: number | null;
  unseenCorrectCount: number;
  unseenAttemptCount: number;
  uniqueQuestionCount: number;
  unseenIndependentAccuracy: number | null;
  smoothedAccuracy: number | null;
  assistedCorrectCount: number;
  assistedAttemptCount: number;
  assistedAccuracy: number | null;
  hintRate: number | null;
  independenceGap: number | null;
  evidenceConfidence: EvidenceConfidence;
  difficultyLevelCount: number;
  medianResponseTimeMs: number | null;
  paceRatio: number | null;
  paceBaselineType: 'calibrated' | 'personal' | null;
  paceAttemptCount: number;
  timeoutRate: number | null;
  trendPercentagePoints: number | null;
  coverageSufficient: boolean;
  recommendedMechanic: LearningMechanic;
  latestEligibleAt: string | null;
  lastPracticedAt: string | null;
  latestStrongEvidenceAt: string | null;
}

export interface SkillProjectionInput {
  attempts: ClassifiedAttempt[];
  asOf: Date;
  retention?: RetentionStateInput | null;
}

export interface RecommendationCandidate {
  taxonomyVersionId: string;
  skillId: string;
  skillLabel: string;
  category: string;
  subcategory: string | null;
  curriculumWeight: number;
  isRequired: boolean;
  inventoryCount: number;
  state: SkillStateProjection;
  assessmentAccuracy: number | null;
  attemptsLast24Hours: number;
  reviewDue: boolean;
  retentionAccuracy: number | null;
}

export interface RankedRecommendation {
  objective: LearningObjective;
  mechanicMode: LearningMechanic;
  questionSelectionType: 'balanced' | 'recommended';
  candidate: RecommendationCandidate;
  priority: number | null;
  availability: {
    runnable: boolean;
    reason: string | null;
    executionAdapter: 'practice_fixed_five' | null;
  };
  reasonEvidence: Array<Record<string, unknown>>;
}
