export const LEARNING_CALCULATION_VERSION = 'learning-v1';
export const EVIDENCE_CLASSIFICATION_VERSION = 'evidence-v1';
export const LEARNING_RECOMMENDATION_TTL_MS = 24 * 60 * 60 * 1000;
export const LEARNING_STATE_ATTEMPT_LIMIT = 20;
export const LEARNING_TREND_BLOCK_SIZE = 10;
export const LEARNING_REVIEW_DELAY_DAYS = 7;
export const LEARNING_STALE_STRONG_EVIDENCE_DAYS = 30;
export const LEARNING_COMPATIBILITY_INVENTORY_MINIMUM = 5;

export const learningV2Enabled = (environment = process.env): boolean =>
  environment.LEARNING_V2_ENABLED?.trim().toLowerCase() === 'true';
