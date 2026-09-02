import { Injectable } from '@nestjs/common';
import type { BattleTarget } from '../../contracts/battle-state';
import type { InternalCategoryDeckState } from './battle.types';
import type { InternalCard } from '../questions/question.types';

@Injectable()
export class QuestionDealer {
  static readonly HAND_SIZE = 3;
  static readonly BUFFER_SIZE = 10;
  static readonly REFILL_THRESHOLD = 3;

  private static readonly CATEGORY_ORDER: Record<BattleTarget, string[]> = {
    cpns: ['twk', 'tiu', 'tkp'],
    bumn: ['wawasan kebangsaan', 'tkd', 'akhlak'],
  };

  private static readonly CATEGORY_ALIASES: Record<
    BattleTarget,
    Readonly<Record<string, string>>
  > = {
    cpns: {
      wk: 'twk',
      'wawasan kebangsaan': 'twk',
      tkd: 'tiu',
      'tes intelegensia umum': 'tiu',
      'tes karakteristik pribadi': 'tkp',
    },
    bumn: {
      wk: 'wawasan kebangsaan',
      twk: 'wawasan kebangsaan',
      tiu: 'tkd',
      'tes kemampuan dasar': 'tkd',
      akhlah: 'akhlak',
      'core values': 'akhlak',
      'core values akhlak': 'akhlak',
    },
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

  private static readonly SUBCATEGORY_ALIASES: Readonly<
    Record<string, string>
  > = {
    kemampuan_verbal: 'verbal',
    kemampuan_numerik: 'numerik',
    kemampuan_logis: 'logis',
    kemampuan_logika: 'logis',
    logika: 'logis',
    kemampuan_figural: 'figural',
    pancasila_ideologi: 'pancasila_dan_ideologi',
    konstitusi_negara: 'konstitusi_dan_negara',
    sejarah_kebangsaan: 'sejarah_dan_kebangsaan',
    pelayanan_integritas: 'pelayanan_dan_integritas',
    kerja_sama_komunikasi: 'kerja_sama_dan_komunikasi',
    adaptasi_pengembangan_diri: 'adaptasi_dan_pengembangan_diri',
    pengambilan_keputusan_kinerja: 'pengambilan_keputusan_dan_kinerja',
  };

  /**
   * Produces a randomized, evenly interleaved queue across the subcategories
   * that are actually available inside one canonical category.
   */
  createBalancedCategoryQueue<T extends { subcategory?: string }>(
    cards: readonly T[],
    requestedCount: number,
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

    const keys = Array.from(groups.keys());
    const selected: T[] = [];

    while (selected.length < count) {
      const cycle = [...keys];
      this.shuffle(cycle, random);
      let drewCard = false;
      for (const key of cycle) {
        const group = groups.get(key);
        if (!group || group.length === 0) continue;
        const card = group.shift();
        if (!card) continue;
        selected.push(card);
        drewCard = true;
        if (selected.length === count) break;
      }
      if (!drewCard) break;
    }
    return selected;
  }

  createSharedQueue(
    cards: InternalCard[],
    target?: BattleTarget,
  ): InternalCard[] {
    return cards.map((card) =>
      target ? this.canonicalizeCard(card, target) : this.cloneCard(card),
    );
  }

  createCategoryDecks(
    sharedQueue: InternalCard[],
    target: BattleTarget,
  ): Record<string, InternalCategoryDeckState> | undefined {
    const grouped = new Map<string, InternalCard[]>();
    for (const card of sharedQueue) {
      const canonicalCard = this.canonicalizeCard(card, target);
      const key = this.categoryKey(canonicalCard.category);
      const cards = grouped.get(key) ?? [];
      cards.push(canonicalCard);
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
    if (!normalized) return '__uncategorized__';
    return QuestionDealer.SUBCATEGORY_ALIASES[normalized] ?? normalized;
  }

  deckCategoryKey(
    target: BattleTarget,
    category?: string,
    _subcategory?: string,
  ): string {
    const normalizedCategory = this.categoryKey(category);
    return (
      QuestionDealer.CATEGORY_ALIASES[target][normalizedCategory] ??
      normalizedCategory
    );
  }

  hasRequiredCategories(
    cards: ReadonlyArray<Pick<InternalCard, 'category'>>,
    target: BattleTarget,
  ): boolean {
    const available = new Set(
      cards.map((card) => this.deckCategoryKey(target, card.category)),
    );
    return QuestionDealer.CATEGORY_ORDER[target].every((category) =>
      available.has(category),
    );
  }

  isValidTaxonomy(
    target: BattleTarget,
    category?: string,
    subcategory?: string,
  ): boolean {
    const canonicalCategory = this.deckCategoryKey(target, category);
    const canonicalSubcategory = this.subcategoryKey(subcategory);
    const allowed = QuestionDealer.SUBCATEGORY_ORDER[target][canonicalCategory];
    return allowed?.includes(canonicalSubcategory) ?? false;
  }

  private categoryKeyForCard(
    card: Pick<InternalCard, 'category' | 'subcategory'>,
    target: BattleTarget,
  ): string {
    return this.deckCategoryKey(target, card.category, card.subcategory);
  }

  private canonicalizeCard(
    card: InternalCard,
    target: BattleTarget,
  ): InternalCard {
    const category = this.categoryKeyForCard(card, target).replace(/\s+/g, '_');
    const subcategory = this.subcategoryKey(card.subcategory);
    return {
      ...card,
      category,
      subcategory:
        subcategory === '__uncategorized__' ? undefined : subcategory,
      options: [...card.options],
    };
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
