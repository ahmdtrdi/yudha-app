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

type RpcAnalyticsRow = {
  category: string;
  subcategory: string | null;
  total_answered: number;
  total_correct: number;
  avg_response_time_ms: number | null;
};

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  async getPerformanceAnalytics(userId: string): Promise<{ data: PerformanceAnalyticsResponse }> {
    const client = this.supabaseService.getClient();

    // Call Supabase RPC for aggregated practice statistics
    const { data: rpcData, error: rpcError } = await (client as any).rpc('get_practice_analytics', {
      p_user_id: userId,
    });

    if (rpcError) {
      this.logger.error(`RPC get_practice_analytics failed for user=${userId}: ${rpcError.message}`);
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

    const practice = this.computePracticeAnalytics((rpcData as unknown as RpcAnalyticsRow[]) ?? []);
    const battle = this.computeBattleAnalytics(profileData);

    return {
      data: {
        practice,
        battle,
      },
    };
  }

  private computePracticeAnalytics(rows: RpcAnalyticsRow[]): PracticeAnalytics {
    if (rows.length === 0) {
      return {
        overallAccuracy: 0,
        totalAnswered: 0,
        categoryBreakdown: [],
        weakSubcategories: [],
        avgResponseTimeMs: 0,
      };
    }

    let totalAnswered = 0;
    let totalCorrect = 0;
    let weightedResponseTimeSum = 0;
    let totalTimeAnswered = 0;

    const catStats = new Map<string, { total: number; correct: number }>();
    const subcatStats = new Map<string, { total: number; correct: number }>();

    for (const row of rows) {
      const answered = Number(row.total_answered ?? 0);
      const correct = Number(row.total_correct ?? 0);
      const category = row.category ?? 'UNKNOWN';
      const subcategory = row.subcategory;

      totalAnswered += answered;
      totalCorrect += correct;

      if (row.avg_response_time_ms != null && answered > 0) {
        weightedResponseTimeSum += Number(row.avg_response_time_ms) * answered;
        totalTimeAnswered += answered;
      }

      // Roll up Category
      const cat = catStats.get(category) ?? { total: 0, correct: 0 };
      cat.total += answered;
      cat.correct += correct;
      catStats.set(category, cat);

      // Roll up Subcategory
      if (subcategory) {
        const sub = subcatStats.get(subcategory) ?? { total: 0, correct: 0 };
        sub.total += answered;
        sub.correct += correct;
        subcatStats.set(subcategory, sub);
      }
    }

    const overallAccuracy =
      totalAnswered === 0 ? 0 : Number(((totalCorrect / totalAnswered) * 100).toFixed(2));

    const avgResponseTimeMs =
      totalTimeAnswered === 0 ? 0 : Math.round(weightedResponseTimeSum / totalTimeAnswered);

    // Build category breakdown
    const categoryBreakdown: CategoryAccuracy[] = Array.from(catStats.entries()).map(([category, stats]) => ({
      category,
      accuracy: stats.total === 0 ? 0 : Number(((stats.correct / stats.total) * 100).toFixed(2)),
      totalAnswered: stats.total,
    }));

    // Build weak subcategories
    const weakSubcategories: WeakSubcategory[] = Array.from(subcatStats.entries())
      .map(([subcategory, stats]) => ({
        subcategory,
        accuracy: stats.total === 0 ? 0 : Number(((stats.correct / stats.total) * 100).toFixed(2)),
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
