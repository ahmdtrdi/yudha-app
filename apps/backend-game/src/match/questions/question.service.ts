import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import {
  QuestionDealer,
  type MatchTopicDistribution,
  type RecommendationTopic,
} from '../engine/question-dealer';
import type { InternalCard, SupabaseQuestionRow } from './question.types';

const DEFAULT_POOL_SIZE = 24;
export const CPNS_ROUND_CATEGORY_LIMITS = {
  TWK: 30,
  TIU: 35,
  TKP: 45,
} as const;
const DECK_CATEGORY_ORDER = [
  'TWK',
  'TIU',
  'TKP',
  'WAWASAN_KEBANGSAAN',
  'TKD',
  'AKHLAK',
] as const;

/** Shape returned when fetching active + reserve card pools */
export type CardPool = {
  /** Cards for the main shared queue (dealt into starting hands and normal draws) */
  active: InternalCard[];
  /** Reserve buffer for recycling when main queue is exhausted */
  reserve: InternalCard[];
};

@Injectable()
export class QuestionService {
  private readonly logger = new Logger(QuestionService.name);

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly dealer: QuestionDealer = new QuestionDealer(),
  ) {}

  /**
   * Fetch a balanced question pool from Supabase for a match, returning both
   * active queue cards and reserve recycling cards.
   *
   * Reads from the base `questions` table (not `public_questions` view)
   * because the game backend needs `correct_option_index` server-side.
   */
  async getMatchQuestionPoolWithReserve(
    target: 'cpns' | 'bumn' = 'cpns',
    activeSize = 12,
    reserveSize = 12,
    recommendationUserIds: readonly string[] = [],
  ): Promise<CardPool> {
    const totalNeeded = activeSize + reserveSize;
    const [data, recommendations] = await Promise.all([
      this.loadActiveQuestions(target),
      this.loadRecommendationTopics(recommendationUserIds, target),
    ]);
    const distribution = this.dealer.createMatchTopicDistribution(
      target,
      recommendations,
    );

    const poolRows = this.buildBalancedPool(data, totalNeeded, distribution);
    const allCards = poolRows.map((row, index) =>
      this.mapToInternalCard(row, index),
    );

    const active = allCards.slice(0, activeSize);
    const reserve = allCards.slice(activeSize);

    return { active, reserve };
  }

  /**
   * Fetch only active question pool (convenience wrapper).
   */
  async getMatchQuestionPool(
    target: 'cpns' | 'bumn' = 'cpns',
    poolSize?: number,
    recommendationUserIds: readonly string[] = [],
  ): Promise<InternalCard[]> {
    if (target === 'cpns' && poolSize === undefined) {
      const [rows, recommendations] = await Promise.all([
        this.loadActiveQuestions(target),
        this.loadRecommendationTopics(recommendationUserIds, target),
      ]);
      const distribution = this.dealer.createMatchTopicDistribution(
        target,
        recommendations,
      );
      return this.buildCpnsRoundPool(rows, distribution).map((row, index) =>
        this.mapToInternalCard(row, index),
      );
    }

    const pool = await this.getMatchQuestionPoolWithReserve(
      target,
      poolSize ?? DEFAULT_POOL_SIZE,
      0,
      recommendationUserIds,
    );
    return pool.active;
  }

  /**
   * Select the real CPNS per-round composition. Categories are never
   * backfilled from one another because each deck has an independent limit.
   */
  buildCpnsRoundPool(
    questions: SupabaseQuestionRow[],
    distribution = this.dealer.createMatchTopicDistribution('cpns', []),
  ): SupabaseQuestionRow[] {
    const byCategory = new Map<string, SupabaseQuestionRow[]>();
    for (const question of questions) {
      const category = this.categoryKey(question.category);
      const rows = byCategory.get(category) ?? [];
      rows.push(question);
      byCategory.set(category, rows);
    }

    const pool: SupabaseQuestionRow[] = [];
    for (const [category, limit] of Object.entries(
      CPNS_ROUND_CATEGORY_LIMITS,
    )) {
      const rows = byCategory.get(this.categoryKey(category)) ?? [];
      pool.push(
        ...this.dealer.createAdaptiveCategoryQueue(
          rows,
          limit,
          this.dealer.topicWeights(distribution, category),
        ),
      );
      if (rows.length < limit) {
        this.logger.warn(
          `${category} only has ${rows.length}/${limit} active questions; the dealer will recycle this category as a fallback.`,
        );
      }
    }
    return pool;
  }

  /**
   * Build a balanced pool from available questions.
   * Distributes evenly across TWK/TIU/TKP categories, shuffles within each,
   * and backfills from other categories if one is short.
   *
   * Pure function (no DB access) — independently unit-testable.
   */
  buildBalancedPool(
    questions: SupabaseQuestionRow[],
    poolSize: number,
    distribution?: MatchTopicDistribution,
  ): SupabaseQuestionRow[] {
    const byCategory = new Map<string, SupabaseQuestionRow[]>();

    // Group by category
    for (const q of questions) {
      const cat = (q.category ?? '').toUpperCase();
      if (!byCategory.has(cat)) byCategory.set(cat, []);
      byCategory.get(cat)!.push(q);
    }

    const target = questions[0]?.target ?? 'cpns';
    const matchDistribution =
      distribution ?? this.dealer.createMatchTopicDistribution(target, []);

    // Each category keeps its own adaptive subcategory order. The existing
    // category round-robin below still preserves the three-deck balance.
    for (const [category, cards] of byCategory) {
      byCategory.set(
        category,
        this.dealer.createAdaptiveCategoryQueue(
          cards,
          cards.length,
          this.dealer.topicWeights(matchDistribution, category),
        ),
      );
    }

    const pool: SupabaseQuestionRow[] = [];
    const availableCategories = Array.from(byCategory.keys());
    const categories = [
      ...DECK_CATEGORY_ORDER.filter((category) => byCategory.has(category)),
      ...availableCategories
        .filter(
          (category) =>
            !DECK_CATEGORY_ORDER.includes(
              category as (typeof DECK_CATEGORY_ORDER)[number],
            ),
        )
        .sort(),
    ];
    while (pool.length < poolSize) {
      let drewQuestion = false;
      for (const category of categories) {
        const question = byCategory.get(category)?.shift();
        if (!question) continue;
        pool.push(question);
        drewQuestion = true;
        if (pool.length === poolSize) break;
      }
      if (!drewQuestion) break;
    }

    if (pool.length < poolSize) {
      this.logger.warn(
        `Question pool only has ${pool.length}/${poolSize} questions — content pool is small.`,
      );
    }

    return pool.slice(0, poolSize);
  }

  /**
   * Map a Supabase question row directly to the engine's InternalCard.
   * damage_value, heal_value, and time_limit_seconds come straight from DB.
   */
  private mapToInternalCard(
    row: SupabaseQuestionRow,
    index: number,
  ): InternalCard {
    return {
      id: `card_${index + 1}`,
      sourceQuestionId: row.id,
      prompt: row.prompt,
      options: [...row.options],
      correctOptionIndex: row.correct_option_index,
      weight: row.weight,
      effect: row.effect,
      category: row.category,
      subcategory: row.subcategory,
      explanation: row.explanation,
      damageValue: row.damage_value,
      healValue: row.heal_value,
      timeLimitSeconds: row.time_limit_seconds,
    };
  }

  private async loadActiveQuestions(
    target: 'cpns' | 'bumn',
  ): Promise<SupabaseQuestionRow[]> {
    const adminClient = this.supabaseService.getAdminClient();
    const { data, error } = await adminClient
      .from('questions')
      .select(
        'id, category, subcategory, prompt, options, correct_option_index, explanation, difficulty, weight, effect, damage_value, heal_value, time_limit_seconds, hint, target, is_active',
      )
      .eq('target', target)
      .eq('is_active', true);

    if (error) {
      throw new Error(`Failed to load question pool: ${error.message}`);
    }
    if (!data || data.length === 0) {
      throw new Error(`No active questions found for target: ${target}`);
    }
    return data as SupabaseQuestionRow[];
  }

  private async loadRecommendationTopics(
    userIds: readonly string[],
    target: 'cpns' | 'bumn',
  ): Promise<Array<RecommendationTopic | null>> {
    if (userIds.length === 0) return [];
    const uniqueUserIds = [...new Set(userIds)];
    const adminClient = this.supabaseService.getAdminClient();
    const { data, error } = await adminClient
      .from('learning_recommendations')
      .select('user_id, target, skill_ids')
      .in('user_id', uniqueUserIds)
      .eq('target', target)
      .eq('status', 'active')
      .eq('availability_runnable', true)
      .eq('question_selection_type', 'recommended')
      .gt('expires_at', new Date().toISOString());

    if (error) {
      this.logger.warn(
        `Recommendation lookup failed; using balanced dealer: ${error.message}`,
      );
      return userIds.map(() => null);
    }

    const topicByUserId = new Map<string, RecommendationTopic>();
    for (const row of (data ?? []) as Array<{
      user_id: string;
      target: string;
      skill_ids: string[];
    }>) {
      const topic = this.parseRecommendationTopic(row.skill_ids?.[0], target);
      if (topic) topicByUserId.set(row.user_id, topic);
    }
    return userIds.map((userId) => topicByUserId.get(userId) ?? null);
  }

  private parseRecommendationTopic(
    skillId: string | undefined,
    target: 'cpns' | 'bumn',
  ): RecommendationTopic | null {
    if (!skillId) return null;
    const [skillTarget, category, ...subcategoryParts] = skillId.split('.');
    const subcategory = subcategoryParts.join('.');
    if (skillTarget !== target || !category || !subcategory) return null;
    return { category, subcategory };
  }

  private categoryKey(category?: string): string {
    return (
      category
        ?.trim()
        .toUpperCase()
        .replace(/[_-]+/g, ' ')
        .replace(/\s+/g, ' ') ?? ''
    );
  }
}
