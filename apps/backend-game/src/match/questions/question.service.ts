import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
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

  constructor(private readonly supabaseService: SupabaseService) {}

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
  ): Promise<CardPool> {
    const totalNeeded = activeSize + reserveSize;
    const data = await this.loadActiveQuestions(target);

    const poolRows = this.buildBalancedPool(data, totalNeeded);
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
  ): Promise<InternalCard[]> {
    if (target === 'cpns' && poolSize === undefined) {
      const rows = await this.loadActiveQuestions(target);
      return this.buildCpnsRoundPool(rows).map((row, index) =>
        this.mapToInternalCard(row, index),
      );
    }

    const pool = await this.getMatchQuestionPoolWithReserve(
      target,
      poolSize ?? DEFAULT_POOL_SIZE,
      0,
    );
    return pool.active;
  }

  /**
   * Select the real CPNS per-round composition. Categories are never
   * backfilled from one another because each deck has an independent limit.
   */
  buildCpnsRoundPool(questions: SupabaseQuestionRow[]): SupabaseQuestionRow[] {
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
      this.shuffle(rows);
      pool.push(...rows.slice(0, limit));
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
  ): SupabaseQuestionRow[] {
    const byCategory = new Map<string, SupabaseQuestionRow[]>();

    // Group by category
    for (const q of questions) {
      const cat = (q.category ?? '').toUpperCase();
      if (!byCategory.has(cat)) byCategory.set(cat, []);
      byCategory.get(cat)!.push(q);
    }

    // Shuffle each category
    for (const [, cards] of byCategory) {
      this.shuffle(cards);
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

  private categoryKey(category?: string): string {
    return (
      category
        ?.trim()
        .toUpperCase()
        .replace(/[_-]+/g, ' ')
        .replace(/\s+/g, ' ') ?? ''
    );
  }

  /** Fisher-Yates shuffle (in-place) */
  private shuffle<T>(array: T[]): void {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }
}
