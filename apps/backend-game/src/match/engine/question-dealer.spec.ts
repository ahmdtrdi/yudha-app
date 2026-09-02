import { QuestionDealer } from './question-dealer';
import type { InternalCard } from '../questions/question.types';

const makeCards = (count: number): InternalCard[] =>
  Array.from({ length: count }, (_, i) => ({
    id: `card_${i + 1}`,
    sourceQuestionId: `question_${i + 1}`,
    prompt: `Question ${i + 1}`,
    options: ['A', 'B', 'C', 'D'],
    correctOptionIndex: 0,
    weight: 1,
    effect: 'damage' as const,
    damageValue: 10,
    healValue: 0,
    timeLimitSeconds: 30,
  }));

describe('QuestionDealer', () => {
  let dealer: QuestionDealer;

  beforeEach(() => {
    dealer = new QuestionDealer();
  });

  describe('HAND_SIZE', () => {
    it('is 3', () => {
      expect(QuestionDealer.HAND_SIZE).toBe(3);
    });
  });

  describe('createSharedQueue', () => {
    it('returns an array with the same length as input', () => {
      const cards = makeCards(8);
      const queue = dealer.createSharedQueue(cards);
      expect(queue).toHaveLength(8);
    });

    it('deep-clones cards so mutations do not affect the source', () => {
      const cards = makeCards(3);
      const queue = dealer.createSharedQueue(cards);

      queue[0].prompt = 'MUTATED';
      queue[0].options[0] = 'MUTATED';

      expect(cards[0].prompt).toBe('Question 1');
      expect(cards[0].options[0]).toBe('A');
    });

    it('preserves card IDs and content', () => {
      const cards = makeCards(2);
      const queue = dealer.createSharedQueue(cards);

      expect(queue[0].id).toBe('card_1');
      expect(queue[1].id).toBe('card_2');
      expect(queue[0].options).toEqual(['A', 'B', 'C', 'D']);
    });

    it.each([
      {
        target: 'cpns' as const,
        category: 'tiu',
        subcategory: 'sejarah_kebangsaan',
        expectedCategory: 'tiu',
        expectedSubcategory: 'sejarah_dan_kebangsaan',
      },
      {
        target: 'bumn' as const,
        category: 'tkd',
        subcategory: 'uud_1945',
        expectedCategory: 'tkd',
        expectedSubcategory: 'uud_1945',
      },
      {
        target: 'bumn' as const,
        category: 'WK',
        subcategory: undefined,
        expectedCategory: 'wawasan_kebangsaan',
        expectedSubcategory: undefined,
      },
    ])(
      'canonicalizes the $target category without using its subcategory',
      ({
        target,
        category,
        subcategory,
        expectedCategory,
        expectedSubcategory,
      }) => {
        const source = {
          ...makeCards(1)[0],
          category,
          subcategory,
        };

        const queue = dealer.createSharedQueue([source], target);

        expect(queue[0].category).toBe(expectedCategory);
        expect(queue[0].subcategory).toBe(expectedSubcategory);
        expect(source.category).toBe(category);
        expect(source.subcategory).toBe(subcategory);
      },
    );
  });

  describe('category buffers', () => {
    const categorizedCards = (): InternalCard[] =>
      ['twk', 'tiu', 'tkp'].flatMap((category) =>
        makeCards(20).map((card, index) => ({
          ...card,
          id: `${category}_${index + 1}`,
          sourceQuestionId: `${category}_question_${index + 1}`,
          category,
        })),
      );

    it('loads ten questions per CPNS category before dealing the hand', () => {
      const decks = dealer.createCategoryDecks(categorizedCards(), 'cpns')!;

      expect(decks.twk.buffer).toHaveLength(10);
      expect(decks.tiu.buffer).toHaveLength(10);
      expect(decks.tkp.buffer).toHaveLength(10);
      expect(decks.twk.reserve).toHaveLength(10);
    });

    it('refills a category with ten questions when its buffer reaches three', () => {
      const decks = dealer.createCategoryDecks(categorizedCards(), 'cpns')!;
      const hand = dealer.createStartingHandFromCategoryDecks(decks, 'cpns');

      expect(hand.map((card) => card.category)).toEqual(['twk', 'tiu', 'tkp']);
      expect(decks.tiu.buffer).toHaveLength(9);

      for (let draw = 0; draw < 6; draw += 1) {
        dealer.drawFromCategoryDeck(decks.tiu);
      }

      expect(decks.tiu.buffer).toHaveLength(13);
      expect(decks.tiu.reserve).toHaveLength(0);
    });

    it('does not recover an unknown CPNS category from its subcategory', () => {
      const cards = categorizedCards();
      for (const card of cards) {
        if (card.category !== 'twk') continue;
        card.category = 'legacy-national-insight';
        card.subcategory = 'sejarah_kebangsaan';
      }

      expect(dealer.createCategoryDecks(cards, 'cpns')).toBeUndefined();
    });

    it('does not recover an unknown BUMN category from its subcategory', () => {
      const cards = [
        ...makeCards(5).map((card) => ({
          ...card,
          category: 'legacy-national-insight',
          subcategory: 'uud_1945',
        })),
        ...makeCards(5).map((card) => ({
          ...card,
          id: `tkd_${card.id}`,
          category: 'tkd',
          subcategory: 'numerik',
        })),
        ...makeCards(5).map((card) => ({
          ...card,
          id: `akhlak_${card.id}`,
          category: 'akhlak',
          subcategory: 'amanah',
        })),
      ];

      expect(dealer.createCategoryDecks(cards, 'bumn')).toBeUndefined();
    });
  });

  describe('balanced subcategory distribution', () => {
    it('deals every subcategory evenly without recommendation weighting', () => {
      const subcategories = ['verbal', 'numerik', 'logis', 'figural'];
      const cards = subcategories.flatMap((subcategory) =>
        makeCards(30).map((card, index) => ({
          ...card,
          id: `${subcategory}_${index}`,
          subcategory,
        })),
      );
      const queue = dealer.createBalancedCategoryQueue(cards, 40, () => 0.9);
      const counts = queue.reduce<Record<string, number>>((result, card) => {
        result[card.subcategory] = (result[card.subcategory] ?? 0) + 1;
        return result;
      }, {});

      expect(counts).toEqual({
        verbal: 10,
        numerik: 10,
        logis: 10,
        figural: 10,
      });
      expect(new Set(queue.map((card) => card.id)).size).toBe(40);
    });

    it('randomizes both topic cycles and cards within each topic', () => {
      const cards = ['verbal', 'numerik'].flatMap((subcategory) =>
        makeCards(3).map((card, index) => ({
          ...card,
          id: `${subcategory}_${index}`,
          subcategory,
        })),
      );

      const low = dealer.createBalancedCategoryQueue(cards, 6, () => 0);
      const high = dealer.createBalancedCategoryQueue(cards, 6, () => 0.999999);

      expect(low.map((card) => card.id)).not.toEqual(
        high.map((card) => card.id),
      );
      expect(new Set(low.map((card) => card.id))).toEqual(
        new Set(high.map((card) => card.id)),
      );
    });

    it('validates subcategories only inside their top-level category', () => {
      expect(dealer.isValidTaxonomy('cpns', 'TIU', 'numerik')).toBe(true);
      expect(dealer.isValidTaxonomy('cpns', 'TIU', 'sejarah_kebangsaan')).toBe(
        false,
      );
      expect(dealer.deckCategoryKey('cpns', 'TIU', 'sejarah_kebangsaan')).toBe(
        'tiu',
      );
    });
  });
});
