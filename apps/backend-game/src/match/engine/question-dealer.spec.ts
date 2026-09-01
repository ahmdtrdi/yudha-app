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
