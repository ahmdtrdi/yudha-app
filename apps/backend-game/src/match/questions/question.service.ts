import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import type { InternalCard, SupabaseQuestionRow, CategoryDistribution } from './question.types';

/**
 * Target pool size per match. Each match draws from this many questions.
 * Configurable here rather than hardcoded in multiple places.
 */
const MATCH_POOL_SIZE = 12;

/**
 * Category distribution: how many questions of each category to include.
 * Must sum to MATCH_POOL_SIZE. Even split across TWK/TIU/TKP.
 */
const CATEGORY_DISTRIBUTION: CategoryDistribution = {
  TWK: 4,
  TIU: 4,
  TKP: 4,
};

@Injectable()
export class QuestionService {
  private readonly logger = new Logger(QuestionService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  /**
   * Fetch a balanced question pool from Supabase for a match.
   * Reads from the base `questions` table (not `public_questions` view)
   * because the game backend needs `correct_option_index` server-side.
   *
   * Questions are fetched once at match creation and cached in room state —
   * no Supabase round-trip happens during open_card/play_card.
   */
  async getMatchQuestionPool(target: 'cpns' | 'bumn', poolSize = MATCH_POOL_SIZE): Promise<InternalCard[]> {
    const adminClient = this.supabaseService.getAdminClient();

    const { data, error } = await adminClient
      .from('questions')
      .select('id, category, subcategory, prompt, options, correct_option_index, explanation, difficulty, weight, effect, damage_value, heal_value, time_limit_seconds, hint, target, is_active')
      .eq('target', target)
      .eq('is_active', true);

    if (error) {
      throw new Error(`Failed to load question pool: ${error.message}`);
    }

    if (!data || data.length === 0) {
      throw new Error(`No active questions found for target: ${target}`);
    }

    const pool = this.buildBalancedPool(data as SupabaseQuestionRow[], poolSize);
    return pool.map((row, index) => this.mapToInternalCard(row, index));
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

    // Draw from each configured category
    for (const [cat, count] of Object.entries(CATEGORY_DISTRIBUTION) as [string, number][]) {
      const available = byCategory.get(cat) ?? [];
      const drawn = available.splice(0, count);
      pool.push(...drawn);
      // Track leftover questions for backfill
      remaining.push(...available);
    }

    // Add any uncategorized questions to the remaining pool
    for (const [cat, cards] of byCategory) {
      if (!(cat in CATEGORY_DISTRIBUTION)) {
        remaining.push(...cards);
      }
    }

    // Backfill if we didn't hit poolSize (some categories had fewer questions)
    if (pool.length < poolSize) {
      this.shuffle(remaining);
      pool.push(...remaining.slice(0, poolSize - pool.length));
    }

    // Final shuffle so categories aren't grouped together in the dealt hand
    this.shuffle(pool);

    if (pool.length < poolSize) {
      this.logger.warn(
        `Question pool only has ${pool.length}/${poolSize} questions — some categories may be underrepresented`,
      );
    }

    return pool.slice(0, poolSize);
  }

  /**
   * Map a Supabase question row directly to the engine's InternalCard.
   * damage_value, heal_value, and time_limit_seconds come straight from the DB —
   * no local recomputation.
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
