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
        expectedCategory: 'twk',
        expectedSubcategory: 'sejarah_dan_kebangsaan',
      },
      {
        target: 'bumn' as const,
        category: 'tkd',
        subcategory: 'uud_1945',
        expectedCategory: 'wawasan_kebangsaan',
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
      'canonicalizes a mismatched $target category from its subcategory',
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

  describe('createStartingHand', () => {
    it('deals exactly HAND_SIZE cards', () => {
      const queue = makeCards(8);
      const hand = dealer.createStartingHand(queue);
      expect(hand).toHaveLength(QuestionDealer.HAND_SIZE);
    });

    it('takes the first HAND_SIZE cards from the queue', () => {
      const queue = makeCards(8);
      const hand = dealer.createStartingHand(queue);

      expect(hand[0].id).toBe('card_1');
      expect(hand[1].id).toBe('card_2');
      expect(hand[2].id).toBe('card_3');
    });

    it('deals one fixed slot for each available category', () => {
      const queue = [
        ...makeCards(2).map((card) => ({ ...card, category: 'twk' })),
        ...makeCards(2).map((card, index) => ({
          ...card,
          id: `tiu_${index}`,
          category: 'tiu',
        })),
        ...makeCards(2).map((card, index) => ({
          ...card,
          id: `tkp_${index}`,
          category: 'tkp',
        })),
      ];

      const hand = dealer.createStartingHand(queue);

      expect(hand.map((card) => card.category)).toEqual(['twk', 'tiu', 'tkp']);
    });

    it('deep-clones cards so mutations do not affect the queue', () => {
      const queue = makeCards(8);
      const hand = dealer.createStartingHand(queue);

      hand[0].prompt = 'MUTATED';
      hand[0].options[0] = 'MUTATED';

      expect(queue[0].prompt).toBe('Question 1');
      expect(queue[0].options[0]).toBe('A');
    });

    it('returns fewer cards if queue is smaller than HAND_SIZE', () => {
      const queue = makeCards(2);
      const hand = dealer.createStartingHand(queue);
      expect(hand).toHaveLength(2);
    });
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

    it('recovers a legacy category from its CPNS subcategory', () => {
      const cards = categorizedCards();
      for (const card of cards) {
        if (card.category !== 'twk') continue;
        card.category = 'legacy-national-insight';
        card.subcategory = 'sejarah_kebangsaan';
      }

      const decks = dealer.createCategoryDecks(cards, 'cpns')!;
      const hand = dealer.createStartingHandFromCategoryDecks(decks, 'cpns');

      expect(decks).toBeDefined();
      expect(hand).toHaveLength(3);
      expect(hand.map((card) => dealer.categoryKey(card.category))).toEqual([
        'twk',
        'tiu',
        'tkp',
      ]);
    });

    it('recovers a legacy category from its BUMN subcategory', () => {
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

      const decks = dealer.createCategoryDecks(cards, 'bumn')!;
      const hand = dealer.createStartingHandFromCategoryDecks(decks, 'bumn');

      expect(decks).toBeDefined();
      expect(hand).toHaveLength(3);
      expect(hand.map((card) => dealer.categoryKey(card.category))).toEqual([
        'wawasan kebangsaan',
        'tkd',
        'akhlak',
      ]);
    });
  });

  describe('adaptive subcategory distribution', () => {
    it('uses the standard 25 percent share for all four subcategories', () => {
      const distribution = dealer.createMatchTopicDistribution('cpns', []);

      expect(distribution.tiu).toEqual({
        verbal: 0.25,
        numerik: 0.25,
        logis: 0.25,
        figural: 0.25,
      });
      expect(distribution.twk.bhinneka_tunggal_ika).toBe(0.25);
      expect(distribution.tkp.pelayanan_dan_integritas).toBe(0.25);
    });

    it('focuses a bot match on the human recommendation topic', () => {
      const distribution = dealer.createMatchTopicDistribution('cpns', [
        { category: 'tiu', subcategory: 'numerik' },
      ]);

      expect(distribution.tiu).toEqual({
        verbal: 0.15,
        numerik: 0.55,
        logis: 0.15,
        figural: 0.15,
      });
      expect(distribution.twk.pancasila_dan_ideologi).toBe(0.25);
    });

    it('averages two PvP recommendations element by element', () => {
      const sameCategory = dealer.createMatchTopicDistribution('cpns', [
        { category: 'tiu', subcategory: 'verbal' },
        { category: 'tiu', subcategory: 'numerik' },
      ]);
      expect(sameCategory.tiu.verbal).toBeCloseTo(0.35);
      expect(sameCategory.tiu.numerik).toBeCloseTo(0.35);
      expect(sameCategory.tiu.logis).toBeCloseTo(0.15);
      expect(sameCategory.tiu.figural).toBeCloseTo(0.15);

      const differentCategories = dealer.createMatchTopicDistribution('cpns', [
        { category: 'tiu', subcategory: 'numerik' },
        { category: 'twk', subcategory: 'bhinneka_tunggal_ika' },
      ]);
      expect(differentCategories.tiu).toEqual({
        verbal: 0.2,
        numerik: 0.4,
        logis: 0.2,
        figural: 0.2,
      });
      expect(differentCategories.twk.bhinneka_tunggal_ika).toBe(0.4);
    });

    it('treats a missing or invalid recommendation as a balanced vector', () => {
      const distribution = dealer.createMatchTopicDistribution('bumn', [
        { category: 'tiu', subcategory: 'numerik' },
        null,
      ]);

      expect(distribution.tkd).toEqual({
        verbal: 0.25,
        numerik: 0.25,
        logis: 0.25,
        figural: 0.25,
      });
    });

    it('deals the requested proportions and interleaves topics smoothly', () => {
      const subcategories = ['verbal', 'numerik', 'logis', 'figural'];
      const cards = subcategories.flatMap((subcategory) =>
        makeCards(30).map((card, index) => ({
          ...card,
          id: `${subcategory}_${index}`,
          subcategory,
        })),
      );
      const weights = dealer.createMatchTopicDistribution('cpns', [
        { category: 'tiu', subcategory: 'numerik' },
      ]).tiu;

      const queue = dealer.createAdaptiveCategoryQueue(
        cards,
        40,
        weights,
        () => 0.999999,
      );
      const counts = queue.reduce<Record<string, number>>((result, card) => {
        result[card.subcategory] = (result[card.subcategory] ?? 0) + 1;
        return result;
      }, {});

      expect(counts).toEqual({ verbal: 6, numerik: 22, logis: 6, figural: 6 });
      expect(
        queue.slice(0, 8).filter((card) => card.subcategory === 'numerik'),
      ).toHaveLength(5);
      expect(new Set(queue.map((card) => card.id)).size).toBe(40);
    });

    it('deals exactly one quarter per topic when the category count is divisible by four', () => {
      const subcategories = ['amanah', 'kompeten', 'harmonis', 'loyal'];
      const cards = subcategories.flatMap((subcategory) =>
        makeCards(10).map((card, index) => ({
          ...card,
          id: `${subcategory}_${index}`,
          subcategory,
        })),
      );
      const weights = dealer.createMatchTopicDistribution('bumn', []).akhlak;

      const queue = dealer.createAdaptiveCategoryQueue(
        cards,
        40,
        weights,
        () => 0.999999,
      );
      const counts = queue.reduce<Record<string, number>>((result, card) => {
        result[card.subcategory] = (result[card.subcategory] ?? 0) + 1;
        return result;
      }, {});

      expect(counts).toEqual({
        amanah: 10,
        kompeten: 10,
        harmonis: 10,
        loyal: 10,
      });
    });
  });

  describe('drawAt', () => {
    it('returns the card at the given index', () => {
      const queue = makeCards(8);
      const card = dealer.drawAt(queue, 4);

      expect(card).toBeDefined();
      expect(card!.id).toBe('card_5');
    });

    it('returns undefined for an out-of-bounds index', () => {
      const queue = makeCards(3);
      expect(dealer.drawAt(queue, 3)).toBeUndefined();
      expect(dealer.drawAt(queue, 100)).toBeUndefined();
    });

    it('deep-clones the returned card', () => {
      const queue = makeCards(5);
      const card = dealer.drawAt(queue, 0)!;

      card.prompt = 'MUTATED';
      card.options[0] = 'MUTATED';

      expect(queue[0].prompt).toBe('Question 1');
      expect(queue[0].options[0]).toBe('A');
    });

    it('does not modify the queue', () => {
      const queue = makeCards(5);
      dealer.drawAt(queue, 2);
      expect(queue).toHaveLength(5);
    });
  });
});
