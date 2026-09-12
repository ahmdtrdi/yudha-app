import { allocateBalancedQuestions } from './solo-delivery-policy';

describe('Solo delivery policy', () => {
  it.each([
    [20, [9, 11]],
    [10, [5, 5]],
    [30, [14, 16]],
  ] as const)(
    'allocates %i CPNS questions across TWK and TIU using 6:7',
    (questionCount, expectedCounts) => {
      expect(allocateBalancedQuestions('cpns', questionCount)).toEqual([
        { category: 'TWK', questionCount: expectedCounts[0] },
        { category: 'TIU', questionCount: expectedCounts[1] },
      ]);
    },
  );

  it.each([
    [20, [15, 5]],
    [10, [8, 2]],
    [30, [23, 7]],
  ] as const)(
    'allocates %i BUMN questions across TKD and AKHLAK using 3:1',
    (questionCount, expectedCounts) => {
      expect(allocateBalancedQuestions('bumn', questionCount)).toEqual([
        { category: 'TKD', questionCount: expectedCounts[0] },
        { category: 'AKHLAK', questionCount: expectedCounts[1] },
      ]);
    },
  );
});
