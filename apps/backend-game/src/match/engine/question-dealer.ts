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

  private static readonly CPNS_ROUND_CAST_LIMITS: Record<string, number> = {
    twk: 30,
    tiu: 35,
    tkp: 45,
  };

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
}
