import { Injectable } from '@nestjs/common';
import type { BattleTarget } from '../../contracts/battle-state';
import type { InternalCategoryDeckState } from './battle.types';
import type { InternalCard } from '../questions/question.types';

export type RecommendationTopic = {
  category: string;
  subcategory: string;
};

export type MatchTopicDistribution = Record<string, Record<string, number>>;

@Injectable()
export class QuestionDealer {
  static readonly HAND_SIZE = 3;
  static readonly BUFFER_SIZE = 10;
  static readonly REFILL_THRESHOLD = 3;

  private static readonly CATEGORY_ORDER: Record<BattleTarget, string[]> = {
    cpns: ['twk', 'tiu', 'tkp'],
    bumn: ['wawasan kebangsaan', 'tkd', 'akhlak'],
  };

  private static readonly CPNS_ROUND_CAST_LIMITS: Record<string, number> = {
    twk: 30,
    tiu: 35,
    tkp: 45,
  };

  private static readonly SUBCATEGORY_ORDER: Record<
    BattleTarget,
    Record<string, string[]>
  > = {
    cpns: {
      twk: [
        'pancasila_dan_ideologi',
        'konstitusi_dan_negara',
        'sejarah_dan_kebangsaan',
        'bhinneka_tunggal_ika',
      ],
      tiu: ['verbal', 'numerik', 'logis', 'figural'],
      tkp: [
        'pelayanan_dan_integritas',
        'kerja_sama_dan_komunikasi',
        'adaptasi_dan_pengembangan_diri',
        'pengambilan_keputusan_dan_kinerja',
      ],
    },
    bumn: {
      'wawasan kebangsaan': [
        'pancasila',
        'uud_1945',
        'nkri',
        'bhinneka_tunggal_ika',
      ],
      tkd: ['verbal', 'numerik', 'logis', 'figural'],
      akhlak: ['amanah', 'kompeten', 'harmonis', 'loyal'],
    },
  };

  private static readonly BASE_WEIGHT = 0.25;
  private static readonly FOCUSED_WEIGHT = 0.55;
  private static readonly NON_FOCUSED_WEIGHT = 0.15;

  /**
   * Builds the match-wide subcategory mix in constant time (at most 24 adds).
   * A missing recommendation contributes the standard 25/25/25/25 vector.
   * PvP passes two entries and receives their element-wise average; bot passes
   * only the human player's entry.
   */
  createMatchTopicDistribution(
    target: BattleTarget,
    recommendations: ReadonlyArray<RecommendationTopic | null | undefined>,
  ): MatchTopicDistribution {
    const participantRecommendations =
      recommendations.length > 0 ? recommendations : [null];
    const distribution = this.emptyDistribution(target);

    for (const recommendation of participantRecommendations) {
      const normalized = this.validRecommendation(target, recommendation);
      for (const [category, subcategories] of Object.entries(
        QuestionDealer.SUBCATEGORY_ORDER[target],
      )) {
        for (const subcategory of subcategories) {
          const focused =
            normalized?.category === category &&
            normalized.subcategory === subcategory;
          const categoryIsFocused = normalized?.category === category;
          distribution[category][subcategory] += categoryIsFocused
            ? focused
              ? QuestionDealer.FOCUSED_WEIGHT
              : QuestionDealer.NON_FOCUSED_WEIGHT
            : QuestionDealer.BASE_WEIGHT;
        }
      }
    }

    const divisor = participantRecommendations.length;
    for (const category of Object.keys(distribution)) {
      for (const subcategory of Object.keys(distribution[category])) {
        distribution[category][subcategory] /= divisor;
      }
    }
    return distribution;
  }

  /**
   * Produces a smoothly interleaved category queue using the supplied topic
   * weights. The hot path is O(cardCount + requestedCount * 4).
   */
  createAdaptiveCategoryQueue<T extends { subcategory?: string }>(
    cards: readonly T[],
    requestedCount: number,
    weights?: Readonly<Record<string, number>>,
    random: () => number = Math.random,
  ): T[] {
    const count = Math.min(
      cards.length,
      Math.max(0, Math.floor(requestedCount)),
    );
    if (count === 0) return [];

    const groups = new Map<string, T[]>();
    for (const card of cards) {
      const key = this.subcategoryKey(card.subcategory);
      const group = groups.get(key) ?? [];
      group.push(card);
      groups.set(key, group);
    }
    for (const group of groups.values()) this.shuffle(group, random);

    const orderedKeys = weights
      ? [
          ...Object.keys(weights),
          ...Array.from(groups.keys()).filter((key) => !(key in weights)),
        ]
      : Array.from(groups.keys()).sort();
    if (orderedKeys.length <= 1 || !weights) {
      const shuffled = [...cards];
      this.shuffle(shuffled, random);
      return shuffled.slice(0, count);
    }

    const positiveWeightTotal = orderedKeys.reduce(
      (sum, key) => sum + Math.max(0, weights[key] ?? 0),
      0,
    );
    const fallbackWeight = 1 / orderedKeys.length;
    const normalizedWeights = Object.fromEntries(
      orderedKeys.map((key) => [
        key,
        positiveWeightTotal > 0
          ? Math.max(0, weights[key] ?? 0) / positiveWeightTotal
          : fallbackWeight,
      ]),
    );
    const credits = Object.fromEntries(orderedKeys.map((key) => [key, 0]));
    const selected: T[] = [];

    while (selected.length < count) {
      let chosen: string | undefined;
      for (const key of orderedKeys) {
        const group = groups.get(key);
        if (!group || group.length === 0) continue;
        credits[key] += normalizedWeights[key];
        if (chosen === undefined || credits[key] > credits[chosen]) {
          chosen = key;
        }
      }
      if (chosen === undefined) break;
      const card = groups.get(chosen)!.shift();
      if (!card) break;
      selected.push(card);
      credits[chosen] -= 1;
    }
    return selected;
  }

  topicWeights(
    distribution: MatchTopicDistribution,
    category?: string,
  ): Record<string, number> | undefined {
    return distribution[this.categoryKey(category)];
  }

  createSharedQueue(cards: InternalCard[]): InternalCard[] {
    return cards.map((card) => ({ ...card, options: [...card.options] }));
  }

  createStartingHand(sharedQueue: InternalCard[]): InternalCard[] {
    const selected: InternalCard[] = [];
    const selectedIds = new Set<string>();
    const categories = new Set<string>();

    for (const card of sharedQueue) {
      const category =
        card.category?.trim().toLowerCase() || '__uncategorized__';
      if (categories.has(category)) continue;
      categories.add(category);
      selected.push(card);
      selectedIds.add(card.id);
      if (selected.length === QuestionDealer.HAND_SIZE) break;
    }

    for (const card of sharedQueue) {
      if (selected.length === QuestionDealer.HAND_SIZE) break;
      if (selectedIds.has(card.id)) continue;
      selectedIds.add(card.id);
      selected.push(card);
    }

    return selected.map((card) => ({
      ...card,
      options: [...card.options],
    }));
  }

  createCategoryDecks(
    sharedQueue: InternalCard[],
    target: BattleTarget,
  ): Record<string, InternalCategoryDeckState> | undefined {
    const grouped = new Map<string, InternalCard[]>();
    for (const card of sharedQueue) {
      const key = this.categoryKey(card.category);
      const cards = grouped.get(key) ?? [];
      cards.push(this.cloneCard(card));
      grouped.set(key, cards);
    }

    const order = QuestionDealer.CATEGORY_ORDER[target];
    if (!order.every((category) => grouped.has(category))) return undefined;

    return Object.fromEntries(
      order.map((category) => {
        const source = grouped
          .get(category)!
          .map((card) => this.cloneCard(card));
        const buffer = source
          .slice(0, QuestionDealer.BUFFER_SIZE)
          .map((card) => this.cloneCard(card));
        const reserve = source
          .slice(QuestionDealer.BUFFER_SIZE)
          .map((card) => this.cloneCard(card));
        return [
          category,
          {
            category,
            buffer,
            reserve,
            source,
            castCount: 0,
            castLimit:
              target === 'cpns'
                ? QuestionDealer.CPNS_ROUND_CAST_LIMITS[category]
                : Number.MAX_SAFE_INTEGER,
          },
        ];
      }),
    );
  }

  createStartingHandFromCategoryDecks(
    decks: Record<string, InternalCategoryDeckState>,
    target: BattleTarget,
  ): InternalCard[] {
    return QuestionDealer.CATEGORY_ORDER[target]
      .map((category) => this.drawFromCategoryDeck(decks[category]))
      .filter((card): card is InternalCard => card !== undefined);
  }

  drawFromCategoryDeck(
    deck: InternalCategoryDeckState,
  ): InternalCard | undefined {
    if (deck.buffer.length === 0) this.refillCategoryDeck(deck, true);
    const card = deck.buffer.shift();
    if (deck.buffer.length <= QuestionDealer.REFILL_THRESHOLD) {
      this.refillCategoryDeck(deck);
    }
    return card ? this.cloneCard(card) : undefined;
  }

  drawAt(sharedQueue: InternalCard[], index: number): InternalCard | undefined {
    const card = sharedQueue[index];
    return card ? this.cloneCard(card) : undefined;
  }

  categoryKey(category?: string): string {
    const normalized = category
      ?.trim()
      .toLowerCase()
      .replace(/[_-]+/g, ' ')
      .replace(/\s+/g, ' ');
    return normalized || '__uncategorized__';
  }

  subcategoryKey(subcategory?: string): string {
    const normalized = subcategory
      ?.trim()
      .toLowerCase()
      .replace(/[\s-]+/g, '_')
      .replace(/_+/g, '_');
    return normalized || '__uncategorized__';
  }

  private emptyDistribution(target: BattleTarget): MatchTopicDistribution {
    return Object.fromEntries(
      Object.entries(QuestionDealer.SUBCATEGORY_ORDER[target]).map(
        ([category, subcategories]) => [
          category,
          Object.fromEntries(
            subcategories.map((subcategory) => [subcategory, 0]),
          ),
        ],
      ),
    );
  }

  private validRecommendation(
    target: BattleTarget,
    recommendation: RecommendationTopic | null | undefined,
  ): RecommendationTopic | null {
    if (!recommendation) return null;
    const category = this.categoryKey(recommendation.category);
    const subcategory = this.subcategoryKey(recommendation.subcategory);
    const allowed = QuestionDealer.SUBCATEGORY_ORDER[target][category];
    return allowed?.includes(subcategory) ? { category, subcategory } : null;
  }

  private refillCategoryDeck(
    deck: InternalCategoryDeckState,
    force = false,
  ): void {
    if (!force && deck.buffer.length > QuestionDealer.REFILL_THRESHOLD) return;
    if (deck.source.length === 0) return;

    let added = 0;
    while (added < QuestionDealer.BUFFER_SIZE) {
      if (deck.reserve.length === 0) {
        deck.reserve.push(...deck.source.map((card) => this.cloneCard(card)));
      }
      const next = deck.reserve.shift();
      if (!next) break;
      deck.buffer.push(this.cloneCard(next));
      added += 1;
    }
  }

  private cloneCard(card: InternalCard): InternalCard {
    return { ...card, options: [...card.options] };
  }

  private shuffle<T>(cards: T[], random: () => number): void {
    for (let index = cards.length - 1; index > 0; index -= 1) {
      const swapIndex = Math.floor(random() * (index + 1));
      [cards[index], cards[swapIndex]] = [cards[swapIndex], cards[index]];
    }
  }
}
