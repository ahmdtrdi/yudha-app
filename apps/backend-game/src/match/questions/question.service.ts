import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import type { InternalCard, SupabaseQuestionRow, CategoryDistribution } from './question.types';

/**
 * Default active pool size per match.
 */
const DEFAULT_ACTIVE_POOL_SIZE = 12;

/**
 * Default reserve pool size for question recycling when active pool is exhausted.
 */
const DEFAULT_RESERVE_POOL_SIZE = 12;

/**
 * Category distribution ratio for building balanced match pools.
 * For a pool of 12, this gives 4 TWK, 4 TIU, 4 TKP.
 */
const CATEGORY_DISTRIBUTION: CategoryDistribution = {
  TWK: 4,
  TIU: 4,
  TKP: 4,
};

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
    activeSize = DEFAULT_ACTIVE_POOL_SIZE,
    reserveSize = DEFAULT_RESERVE_POOL_SIZE,
  ): Promise<CardPool> {
    const totalNeeded = activeSize + reserveSize;
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

    const poolRows = this.buildBalancedPool(data as SupabaseQuestionRow[], totalNeeded);
    const allCards = poolRows.map((row, index) => this.mapToInternalCard(row, index));

    const active = allCards.slice(0, activeSize);
    const reserve = allCards.slice(activeSize);

    return { active, reserve };
  }

  /**
   * Fetch only active question pool (convenience wrapper).
   */
  async getMatchQuestionPool(
    target: 'cpns' | 'bumn' = 'cpns',
    poolSize = DEFAULT_ACTIVE_POOL_SIZE,
  ): Promise<InternalCard[]> {
    const pool = await this.getMatchQuestionPoolWithReserve(target, poolSize, 0);
    return pool.active;
  }

  /**
   * Build a balanced pool from available questions.
   * Distributes evenly across TWK/TIU/TKP categories, shuffles within each,
   * and backfills from other categories if one is short.
   *
   * Pure function (no DB access) — independently unit-testable.
   */
  buildBalancedPool(questions: SupabaseQuestionRow[], poolSize: number): SupabaseQuestionRow[] {
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
    const remaining: SupabaseQuestionRow[] = [];

    // Scale category target based on requested pool size
    const scale = poolSize / DEFAULT_ACTIVE_POOL_SIZE;

    // Draw from each configured category
    for (const [cat, count] of Object.entries(CATEGORY_DISTRIBUTION) as [string, number][]) {
      const targetCount = Math.round(count * scale);
      const available = byCategory.get(cat) ?? [];
      const drawn = available.splice(0, targetCount);
      pool.push(...drawn);
      remaining.push(...available);
    }

    // Add any uncategorized categories to remaining
    for (const [cat, cards] of byCategory) {
      if (!(cat in CATEGORY_DISTRIBUTION)) {
        remaining.push(...cards);
      }
    }

    // Backfill if we didn't hit poolSize
    if (pool.length < poolSize) {
      this.shuffle(remaining);
      pool.push(...remaining.slice(0, poolSize - pool.length));
    }

    // Final shuffle so categories aren't grouped sequentially in hand
    this.shuffle(pool);

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
  private mapToInternalCard(row: SupabaseQuestionRow, index: number): InternalCard {
    return {
      id: `card_${index + 1}`,
      prompt: row.prompt,
      options: [...row.options],
      correctOptionIndex: row.correct_option_index,
      weight: row.weight,
      effect: row.effect,
      explanation: row.explanation,
      damageValue: row.damage_value,
      healValue: row.heal_value,
      timeLimitSeconds: row.time_limit_seconds,
    };
  }

  /** Fisher-Yates shuffle (in-place) */
  private shuffle<T>(array: T[]): void {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }
}
