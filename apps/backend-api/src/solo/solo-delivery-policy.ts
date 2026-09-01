import {
  SOLO_QUESTION_COUNTS,
  type SoloQuestionCount,
} from './solo-contract.types';

export const SOLO_FIXED_COUNT_POLICY_ID = 'solo-fixed-count-v1';
export const SOLO_FIXED_COUNT_POLICY_VERSION = 1;

export const SOLO_BALANCED_CATEGORY_WEIGHTS = {
  cpns: [
    { category: 'TWK', weight: 6 },
    { category: 'TIU', weight: 7 },
  ],
  bumn: [
    { category: 'TKD', weight: 3 },
    { category: 'AKHLAK', weight: 1 },
  ],
} as const;

export type SoloTarget = keyof typeof SOLO_BALANCED_CATEGORY_WEIGHTS;

export interface SoloCategoryAllocation {
  category: string;
  questionCount: number;
}

export function allocateBalancedQuestions(
  target: SoloTarget,
  questionCount: SoloQuestionCount,
): SoloCategoryAllocation[] {
  if (!SOLO_QUESTION_COUNTS.includes(questionCount)) {
    throw new Error(`Unsupported Solo question count: ${questionCount}`);
  }

  const categories = SOLO_BALANCED_CATEGORY_WEIGHTS[target];
  const totalWeight = categories.reduce(
    (total, category) => total + category.weight,
    0,
  );
  const allocations = categories.map((category, index) => {
    const exact = (questionCount * category.weight) / totalWeight;
    const base = Math.floor(exact);
    return {
      category: category.category,
      questionCount: base,
      remainder: exact - base,
      index,
    };
  });

  let unallocated =
    questionCount -
    allocations.reduce(
      (total, allocation) => total + allocation.questionCount,
      0,
    );
  const byRemainder = [...allocations].sort(
    (left, right) =>
      right.remainder - left.remainder || left.index - right.index,
  );

  for (const allocation of byRemainder) {
    if (unallocated === 0) break;
    allocation.questionCount += 1;
    unallocated -= 1;
  }

  return allocations.map(({ category, questionCount: count }) => ({
    category,
    questionCount: count,
  }));
}
