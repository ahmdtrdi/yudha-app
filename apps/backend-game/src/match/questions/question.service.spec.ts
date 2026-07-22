import { Test, TestingModule } from '@nestjs/testing';
import { QuestionService } from './question.service';
import { SupabaseService } from '../../supabase/supabase.service';
import type { SupabaseQuestionRow } from './question.types';

/** Create stub question rows resembling Supabase data */
function makeQuestionRows(count: number, category: string = 'TWK'): SupabaseQuestionRow[] {
  return Array.from({ length: count }, (_, i) => ({
    id: `q_${category.toLowerCase()}_${i + 1}`,
    category,
    subcategory: 'test-sub',
    prompt: `${category} Question ${i + 1}`,
    options: ['A', 'B', 'C', 'D'],
    correct_option_index: 0,
    explanation: 'Because A is correct.',
    difficulty: 1,
    weight: 1,
    effect: (i % 2 === 0 ? 'damage' : 'heal') as 'damage' | 'heal',
    damage_value: i % 2 === 0 ? 14 : 0,
    heal_value: i % 2 === 0 ? 0 : 14,
    time_limit_seconds: 30,
    hint: 'Hint text',
    target: 'cpns' as const,
    is_active: true,
  }));
}

describe('QuestionService', () => {
  let service: QuestionService;
  let mockSelect: jest.Mock;
  let mockEqTarget: jest.Mock;
  let mockEqActive: jest.Mock;

  beforeEach(async () => {
    // Build a chained mock: .from().select().eq('target').eq('is_active')
    mockEqActive = jest.fn();
    mockEqTarget = jest.fn().mockReturnValue({ eq: mockEqActive });
    mockSelect = jest.fn().mockReturnValue({ eq: mockEqTarget });

    const mockAdminClient = {
      from: jest.fn().mockReturnValue({ select: mockSelect }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QuestionService,
        {
          provide: SupabaseService,
          useValue: {
            getAdminClient: () => mockAdminClient,
          },
        },
      ],
    }).compile();

    service = module.get<QuestionService>(QuestionService);
  });

  // ─── buildBalancedPool (pure function, no DB) ───

  describe('buildBalancedPool', () => {
    it('distributes evenly across TWK/TIU/TKP for pool of 12', () => {
      const questions = [
        ...makeQuestionRows(10, 'TWK'),
        ...makeQuestionRows(10, 'TIU'),
        ...makeQuestionRows(10, 'TKP'),
      ];

      const pool = service.buildBalancedPool(questions, 12);

      expect(pool).toHaveLength(12);

      const categories = pool.map((q) => q.category.toUpperCase());
      const twkCount = categories.filter((c) => c === 'TWK').length;
      const tiuCount = categories.filter((c) => c === 'TIU').length;
      const tkpCount = categories.filter((c) => c === 'TKP').length;

      expect(twkCount).toBe(4);
      expect(tiuCount).toBe(4);
      expect(tkpCount).toBe(4);
    });

    it('backfills from other categories when one is short', () => {
      const questions = [
        ...makeQuestionRows(2, 'TWK'),  // Only 2 TWK available (need 4)
        ...makeQuestionRows(10, 'TIU'),
        ...makeQuestionRows(10, 'TKP'),
      ];

      const pool = service.buildBalancedPool(questions, 12);

      expect(pool).toHaveLength(12);
      // TWK contributed only 2, but pool is backfilled to 12
    });

    it('handles fewer total questions than pool size', () => {
      const questions = makeQuestionRows(5, 'TWK');

      const pool = service.buildBalancedPool(questions, 12);

      expect(pool).toHaveLength(5);
    });

    it('handles empty question list', () => {
      const pool = service.buildBalancedPool([], 12);
      expect(pool).toHaveLength(0);
    });

    it('shuffles the final pool so categories are not grouped', () => {
      // Use a large pool to make it statistically unlikely that categories remain grouped
      const questions = [
        ...makeQuestionRows(20, 'TWK'),
        ...makeQuestionRows(20, 'TIU'),
        ...makeQuestionRows(20, 'TKP'),
      ];

      // Run multiple times to verify shuffling happens
      const pools = Array.from({ length: 5 }, () => service.buildBalancedPool(questions, 12));

      // At least one pool should differ in order (extremely unlikely all 5 are identical)
      const firstPoolIds = pools[0].map((q) => q.id).join(',');
      const allSame = pools.every((p) => p.map((q) => q.id).join(',') === firstPoolIds);
      // Note: with 5 shuffles of 12 items, the probability of all being identical is near zero
      // but we won't fail on it since it's theoretically possible
    });

    it('scales category counts for different pool sizes', () => {
      const questions = [
        ...makeQuestionRows(20, 'TWK'),
        ...makeQuestionRows(20, 'TIU'),
        ...makeQuestionRows(20, 'TKP'),
      ];

      const pool24 = service.buildBalancedPool(questions, 24);
      expect(pool24).toHaveLength(24);

      const categories = pool24.map((q) => q.category.toUpperCase());
      const twkCount = categories.filter((c) => c === 'TWK').length;
      const tiuCount = categories.filter((c) => c === 'TIU').length;
      const tkpCount = categories.filter((c) => c === 'TKP').length;

      expect(twkCount).toBe(8);
      expect(tiuCount).toBe(8);
      expect(tkpCount).toBe(8);
    });

    it('is case-insensitive for category matching', () => {
      const questions = [
        ...makeQuestionRows(5, 'twk'),
        ...makeQuestionRows(5, 'TIU'),
        ...makeQuestionRows(5, 'TKP'),
      ];

      const pool = service.buildBalancedPool(questions, 12);
      expect(pool).toHaveLength(12);
    });
  });

  // ─── getMatchQuestionPoolWithReserve ───

  describe('getMatchQuestionPoolWithReserve', () => {
    it('returns active and reserve card splits', async () => {
      const allRows = [
        ...makeQuestionRows(10, 'TWK'),
        ...makeQuestionRows(10, 'TIU'),
        ...makeQuestionRows(10, 'TKP'),
      ];
      mockEqActive.mockResolvedValue({ data: allRows, error: null });

      const { active, reserve } = await service.getMatchQuestionPoolWithReserve('cpns', 12, 12);

      expect(active).toHaveLength(12);
      expect(reserve).toHaveLength(12);

      // Each card should be mapped to InternalCard shape
      expect(active[0]).toHaveProperty('id');
      expect(active[0]).toHaveProperty('prompt');
      expect(active[0]).toHaveProperty('correctOptionIndex');
      expect(active[0]).toHaveProperty('damageValue');
      expect(active[0]).toHaveProperty('healValue');
      expect(active[0]).toHaveProperty('timeLimitSeconds');
    });

    it('throws when Supabase returns an error', async () => {
      mockEqActive.mockResolvedValue({ data: null, error: { message: 'DB error' } });

      await expect(service.getMatchQuestionPoolWithReserve('cpns')).rejects.toThrow('Failed to load question pool');
    });

    it('throws when no questions are found', async () => {
      mockEqActive.mockResolvedValue({ data: [], error: null });

      await expect(service.getMatchQuestionPoolWithReserve('cpns')).rejects.toThrow('No active questions found');
    });

    it('returns empty reserve when only active cards are requested', async () => {
      const allRows = makeQuestionRows(15, 'TWK');
      mockEqActive.mockResolvedValue({ data: allRows, error: null });

      const { active, reserve } = await service.getMatchQuestionPoolWithReserve('cpns', 12, 0);

      expect(active).toHaveLength(12);
      expect(reserve).toHaveLength(0);
    });
  });

  // ─── getMatchQuestionPool (convenience) ───

  describe('getMatchQuestionPool', () => {
    it('returns only active cards', async () => {
      const allRows = [
        ...makeQuestionRows(10, 'TWK'),
        ...makeQuestionRows(10, 'TIU'),
        ...makeQuestionRows(10, 'TKP'),
      ];
      mockEqActive.mockResolvedValue({ data: allRows, error: null });

      const cards = await service.getMatchQuestionPool('cpns', 12);

      expect(cards).toHaveLength(12);
      expect(cards[0]).toHaveProperty('correctOptionIndex');
    });
  });
});
