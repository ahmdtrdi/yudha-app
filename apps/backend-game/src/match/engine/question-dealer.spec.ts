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
    it('is 4', () => {
      expect(QuestionDealer.HAND_SIZE).toBe(4);
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
      expect(hand[3].id).toBe('card_4');
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
