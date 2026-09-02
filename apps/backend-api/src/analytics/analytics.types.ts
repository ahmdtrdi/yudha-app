export interface TopicMetric {
  target: string;
  category: string;
  subcategory: string | null;
  accuracy: number;
  sampleSize: number;
  averageResponseTimeMs: number;
  lastPracticedAt: string | null;
}

export interface RecommendationMetrics {
  sampleSize: number;
  accuracy: number | null;
  lastPracticedAt: string | null;
}

export type LearningRecommendation =
  | {
      type: 'practice';
      target: string;
      category?: string;
      subcategory?: string;
      reason: string;
      metrics: RecommendationMetrics;
    }
  | {
      type: 'interview';
      reason: string;
      lastCompletedAt: string | null;
    };

export interface AnswerObservation {
  target: string;
  category: string;
  subcategory: string | null;
  isCorrect: boolean;
  responseTimeMs: number | null;
  answeredAt: string;
  source: 'practice' | 'ranked';
}

export interface LearningAnalytics {
  window: {
    businessDays: 90;
    startsAt: string;
    endsAt: string;
  };
  practice: {
    accuracy: number;
    averageResponseTimeMs: number;
    sampleSize: number;
    categoryBreakdown: TopicMetric[];
    subcategoryBreakdown: TopicMetric[];
  };
  ranked: {
    accuracy: number;
    averageResponseTimeMs: number;
    sampleSize: number;
  };
  weakTopics: TopicMetric[];
  publicMatches: {
    wins: number;
    losses: number;
    draws: number;
    sampleSize: number;
    winRate: number;
  };
  streak: {
    current: number;
    best: number;
    lastDate: string | null;
  };
  history: {
    practice: unknown[];
    ranked: unknown[];
  };
  recommendation: LearningRecommendation;
}
