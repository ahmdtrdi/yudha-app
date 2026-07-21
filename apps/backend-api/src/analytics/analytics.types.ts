export interface CategoryAccuracy {
  category: string;
  accuracy: number;
  totalAnswered: number;
}

export interface WeakSubcategory {
  subcategory: string;
  accuracy: number;
  totalAnswered: number;
}

export interface PracticeAnalytics {
  overallAccuracy: number;
  totalAnswered: number;
  categoryBreakdown: CategoryAccuracy[];
  weakSubcategories: WeakSubcategory[];
  avgResponseTimeMs: number;
}

export interface BattleAnalytics {
  winrate: number;
  wins: number;
  losses: number;
  totalMatches: number;
}

export interface PerformanceAnalyticsResponse {
  practice: PracticeAnalytics;
  battle: BattleAnalytics;
}
