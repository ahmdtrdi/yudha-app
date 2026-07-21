import { Injectable } from '@nestjs/common';
import type { InternalCard, QuestionSeed } from './question.types';

/**
 * Pool size for the active shared queue (cards that are dealt into hands).
 * The reserve buffer adds more cards beyond this for recycling.
 */
const ACTIVE_POOL_SIZE = 12;

const LOCAL_QUESTIONS: QuestionSeed[] = [
  {
    id: 'q_sequence_1',
    prompt: '2, 4, 8, 16, ...',
    options: ['18', '24', '32', '36'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
  },
  {
    id: 'q_logic_1',
    prompt: 'All pilots are disciplined. Some disciplined people are athletes. Which conclusion is certain?',
    options: [
      'Some pilots are athletes',
      'All athletes are pilots',
      'Some disciplined people may be pilots',
      'No athlete is disciplined',
    ],
    correctOptionIndex: 2,
    weight: 2,
    effect: 'heal',
  },
  {
    id: 'q_math_1',
    prompt: 'If 3x + 5 = 20, what is x?',
    options: ['3', '4', '5', '6'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
  },
  {
    id: 'q_sequence_2',
    prompt: '1, 1, 2, 3, 5, ...',
    options: ['6', '7', '8', '9'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
  },
  {
    id: 'q_logic_2',
    prompt: 'A is taller than B. B is taller than C. Who is shortest?',
    options: ['A', 'B', 'C', 'Cannot be known'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'heal',
  },
  {
    id: 'q_math_2',
    prompt: 'What is 25% of 80?',
    options: ['10', '15', '20', '25'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
  },
  {
    id: 'q_sequence_3',
    prompt: '5, 10, 20, 40, ...',
    options: ['45', '60', '80', '100'],
    correctOptionIndex: 2,
    weight: 2,
    effect: 'damage',
  },
  {
    id: 'q_logic_3',
    prompt: 'If today is Monday, what day is 10 days later?',
    options: ['Wednesday', 'Thursday', 'Friday', 'Saturday'],
    correctOptionIndex: 1,
    weight: 1,
    effect: 'heal',
  },
  {
    id: 'q_math_3',
    prompt: '12 x 7 = ?',
    options: ['72', '78', '84', '96'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
  },
  {
    id: 'q_logic_4',
    prompt: 'Find the odd one out.',
    options: ['Triangle', 'Square', 'Circle', 'Honest'],
    correctOptionIndex: 3,
    weight: 2,
    effect: 'damage',
  },
  {
    id: 'q_math_4',
    prompt: 'A train travels 60 km in 1.5 hours. Its speed is...',
    options: ['30 km/h', '35 km/h', '40 km/h', '45 km/h'],
    correctOptionIndex: 2,
    weight: 2,
    effect: 'damage',
  },
  {
    id: 'q_sequence_4',
    prompt: '3, 6, 11, 18, 27, ...',
    options: ['34', '36', '38', '40'],
    correctOptionIndex: 2,
    weight: 3,
    effect: 'heal',
  },
];

/** Shape returned by getCardPool — split into active and reserve sets */
export type CardPool = {
  /** Cards for the main shared queue (dealt into hands) */
  active: InternalCard[];
  /** Reserve buffer for recycling when main queue is exhausted */
  reserve: InternalCard[];
};

@Injectable()
export class QuestionService {
  /**
   * Get the full card pool, split into active and reserve sets.
   * The active set feeds the main shared queue; the reserve is used
   * for recycling when the active pool is exhausted (PRD §3.1 step 6).
   *
   * When backed by Supabase (future), this will fetch 2x the pool size
   * and split it — no mid-battle DB query.
   */
  getCardPool(): CardPool {
    const allCards = this.buildAllCards();
    const active = allCards.slice(0, ACTIVE_POOL_SIZE);
    const reserve = allCards.slice(ACTIVE_POOL_SIZE);
    return { active, reserve };
  }

  /** Legacy method — returns just the active pool (backward compat for existing callers) */
  getCards(): InternalCard[] {
    return this.getCardPool().active;
  }

  private buildAllCards(): InternalCard[] {
    return LOCAL_QUESTIONS.map((question, index) => {
      this.validateQuestion(question);
      const effectValue = this.effectValue(question.weight);
      return {
        id: `card_${index + 1}`,
        prompt: question.prompt,
        options: [...question.options],
        correctOptionIndex: question.correctOptionIndex,
        weight: question.weight,
        effect: question.effect,
        explanation: question.explanation,
        damageValue: question.effect === 'damage' ? effectValue : 0,
        healValue: question.effect === 'heal' ? Math.max(5, Math.floor(effectValue / 2)) : 0,
      };
    });
  }

  private validateQuestion(question: QuestionSeed): void {
    if (
      !question.id ||
      !question.prompt ||
      question.options.length !== 4 ||
      !Number.isInteger(question.correctOptionIndex) ||
      question.correctOptionIndex < 0 ||
      question.correctOptionIndex >= question.options.length ||
      question.weight < 1
    ) {
      throw new Error(`Invalid local question seed: ${question.id}`);
    }
  }

  private effectValue(weight: number): number {
    return 8 + weight * 6;
  }
}
