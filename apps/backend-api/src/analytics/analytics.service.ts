import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import type {
  BattleAnalytics,
  CategoryAccuracy,
  PerformanceAnalyticsResponse,
  PracticeAnalytics,
  WeakSubcategory,
} from './analytics.types';

const WEAK_SUBCATEGORY_ACCURACY_THRESHOLD = 60.0;
const WEAK_SUBCATEGORY_MIN_SAMPLE_SIZE = 5;

type AnswerWithQuestion = {
  is_correct: boolean;
  response_time_ms: number | null;
  questions: {
    category: string;
    subcategory: string | null;
  } | null;
};

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  async getPerformanceAnalytics(userId: string): Promise<{ data: PerformanceAnalyticsResponse }> {
    const client = this.supabaseService.getClient();

    // Fetch practice answer history with question categories
    const { data: answersData, error: answersError } = await (client as any)
      .from('practice_answers')
      .select('is_correct, response_time_ms, questions(category, subcategory)')
      .eq('user_id', userId);

    if (answersError) {
      this.logger.error(`Failed to fetch practice answers for analytics (user=${userId}): ${answersError.message}`);
    }

    // Fetch profile battle statistics
    const { data: profileData, error: profileError } = await client
      .from('profiles')
      .select('wins, losses, total_matches, winrate')
      .eq('id', userId)
      .maybeSingle();

    if (profileError) {
      this.logger.error(`Failed to fetch profile stats for analytics (user=${userId}): ${profileError.message}`);
    }

    const practice = this.computePracticeAnalytics((answersData as AnswerWithQuestion[]) ?? []);
    const battle = this.computeBattleAnalytics(profileData);

    return {
      data: {
        practice,
        battle,
      },
    };
  }

  private computePracticeAnalytics(answers: AnswerWithQuestion[]): PracticeAnalytics {
    if (answers.length === 0) {
      return {
        overallAccuracy: 0,
        totalAnswered: 0,
        categoryBreakdown: [],
        weakSubcategories: [],
        avgResponseTimeMs: 0,
      };
    }

    const totalAnswered = answers.length;
    const correctCount = answers.filter((a) => a.is_correct).length;
    const overallAccuracy = Number(((correctCount / totalAnswered) * 100).toFixed(2));

    // Response time
    const validTimes = answers
      .map((a) => a.response_time_ms)
      .filter((t): t is number => typeof t === 'number' && t >= 0);
    const avgResponseTimeMs =
      validTimes.length === 0
        ? 0
        : Math.round(validTimes.reduce((sum, val) => sum + val, 0) / validTimes.length);

    // Grouping by category and subcategory
    const catStats = new Map<string, { total: number; correct: number }>();
    const subcatStats = new Map<string, { total: number; correct: number }>();

    for (const answer of answers) {
      const category = answer.questions?.category ?? 'UNKNOWN';
      const subcategory = answer.questions?.subcategory;

      // Category
      const cat = catStats.get(category) ?? { total: 0, correct: 0 };
      cat.total += 1;
      if (answer.is_correct) cat.correct += 1;
      catStats.set(category, cat);

      // Subcategory
      if (subcategory) {
        const sub = subcatStats.get(subcategory) ?? { total: 0, correct: 0 };
        sub.total += 1;
        if (answer.is_correct) sub.correct += 1;
        subcatStats.set(subcategory, sub);
      }
    }

    // Build category breakdown
    const categoryBreakdown: CategoryAccuracy[] = Array.from(catStats.entries()).map(([category, stats]) => ({
      category,
      accuracy: Number(((stats.correct / stats.total) * 100).toFixed(2)),
      totalAnswered: stats.total,
    }));

    // Build weak subcategories
    const weakSubcategories: WeakSubcategory[] = Array.from(subcatStats.entries())
      .map(([subcategory, stats]) => ({
        subcategory,
        accuracy: Number(((stats.correct / stats.total) * 100).toFixed(2)),
        totalAnswered: stats.total,
      }))
      .filter(
        (sub) =>
          sub.totalAnswered >= WEAK_SUBCATEGORY_MIN_SAMPLE_SIZE &&
          sub.accuracy < WEAK_SUBCATEGORY_ACCURACY_THRESHOLD,
      )
      .sort((a, b) => a.accuracy - b.accuracy);

    return {
      overallAccuracy,
      totalAnswered,
      categoryBreakdown,
      weakSubcategories,
      avgResponseTimeMs,
    };
  }

  private computeBattleAnalytics(
    profile: { wins: number; losses: number; total_matches: number; winrate: number } | null,
  ): BattleAnalytics {
    if (!profile) {
      return {
        winrate: 0,
        wins: 0,
        losses: 0,
        totalMatches: 0,
      };
    }

    return {
      winrate: Number(profile.winrate ?? 0),
      wins: profile.wins ?? 0,
      losses: profile.losses ?? 0,
      totalMatches: profile.total_matches ?? 0,
    };
  }
}
