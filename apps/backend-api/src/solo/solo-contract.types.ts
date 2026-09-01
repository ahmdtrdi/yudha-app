export const SOLO_MECHANIC_MODES = ['focus', 'standard', 'speed'] as const;

export type SoloMechanicMode = (typeof SOLO_MECHANIC_MODES)[number];

export const SOLO_QUESTION_SELECTION_TYPES = [
  'balanced',
  'recommended',
  'custom',
] as const;

export type SoloQuestionSelectionType =
  (typeof SOLO_QUESTION_SELECTION_TYPES)[number];

export const SOLO_QUESTION_COUNTS = [20, 35, 50] as const;

export type SoloQuestionCount = (typeof SOLO_QUESTION_COUNTS)[number];

export interface SoloBalancedQuestionSelection {
  type: 'balanced';
}

export interface SoloRecommendedQuestionSelection {
  type: 'recommended';
}

export interface SoloCustomQuestionSelection {
  type: 'custom';
  skillIds: string[];
}

export type SoloQuestionSelection =
  | SoloBalancedQuestionSelection
  | SoloRecommendedQuestionSelection
  | SoloCustomQuestionSelection;

export interface SoloSessionConfiguration {
  mechanicMode: SoloMechanicMode;
  questionCount: SoloQuestionCount;
  questionSelection: SoloQuestionSelection;
  recommendationId?: string;
}

export interface SoloDraftSessionRequest extends SoloSessionConfiguration {
  idempotencyKey: string;
  characterId: string;
}

export const SOLO_COMPATIBILITY_WARNING_CODES = [
  'speed_baseline_unavailable',
  'focus_recommended_before_speed',
  'recommendation_unavailable',
] as const;

export type SoloCompatibilityWarningCode =
  (typeof SOLO_COMPATIBILITY_WARNING_CODES)[number];

export interface SoloCompatibilityWarning {
  code: SoloCompatibilityWarningCode;
  message: string;
}

export interface SoloConfigurationResolution {
  requested: SoloSessionConfiguration;
  effectiveMechanicMode: SoloMechanicMode | null;
  effectiveQuestionSelection: SoloQuestionSelection | null;
  warnings: SoloCompatibilityWarning[];
  operational: boolean;
}

export const SOLO_CONTRACT_ERROR_CODES = [
  'SOLO_CONFIGURATION_INVALID',
  'SOLO_CONFIGURATION_UNSUPPORTED',
] as const;

export type SoloContractErrorCode = (typeof SOLO_CONTRACT_ERROR_CODES)[number];

export interface LegacyPracticeCompatibility {
  canonicalActivity: 'solo';
  source: 'practice';
  evidenceFidelity: 'legacy';
  legacyFilter: {
    category: string | null;
    subcategory: string | null;
  };
  effectiveMechanicMode: null;
  effectiveQuestionSelection: null;
  limitations: readonly string[];
}
