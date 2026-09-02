export type PvpAnalyticsWindow = '7d' | '30d' | 'all';
export type PvpAnalyticsMode = 'all' | 'ranked' | 'casual';

export interface PvpAnalyticsQuery {
  window?: string;
  mode?: string;
}

export interface PvpTopicMetric {
  taxonomyVersionId: string;
  skillId: string;
  category: string | null;
  subcategory: string | null;
  attempts: number;
  correct: number;
  uniqueQuestions: number;
  difficultyCount: number;
  accuracy: number;
  smoothedAccuracy: number;
  timeoutRate: number;
  medianResponseTimeMs: number | null;
  evidenceStrength: 'low' | 'medium' | 'high';
  repairScore: number;
}
