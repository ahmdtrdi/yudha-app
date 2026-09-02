import { Test, TestingModule } from '@nestjs/testing';
import { QuestionService } from './question.service';
import { SupabaseService } from '../../supabase/supabase.service';
import { QuestionDealer } from '../engine/question-dealer';
import type { SupabaseQuestionRow } from './question.types';

/** Create stub question rows resembling Supabase data */
function makeQuestionRows(
  count: number,
  category: string = 'TWK',
  target: 'cpns' | 'bumn' = 'cpns',
): SupabaseQuestionRow[] {
  const normalizedCategory = category.toLowerCase().replace(/[_-]+/g, ' ');
  const defaultSubcategory =
    target === 'bumn'
      ? normalizedCategory === 'tkd'
        ? 'verbal'
        : normalizedCategory === 'akhlak'
          ? 'amanah'
          : 'pancasila'
      : normalizedCategory === 'tiu'
        ? 'verbal'
        : normalizedCategory === 'tkp'
          ? 'pelayanan_dan_integritas'
          : 'pancasila_dan_ideologi';
  return Array.from({ length: count }, (_, i) => ({
    id: `q_${category.toLowerCase()}_${i + 1}`,
    category,
    subcategory: defaultSubcategory,
    prompt: `${category} Question ${i + 1}`,
    options: ['A', 'B', 'C', 'D'],
    correct_option_index: 0,
    explanation: 'Because A is correct.',
    difficulty: 1,
    weight: 1,
    effect: i % 2 === 0 ? 'damage' : 'heal',
    damage_value: i % 2 === 0 ? 14 : 0,
    heal_value: i % 2 === 0 ? 0 : 14,
    time_limit_seconds: 30,
    hint: 'Hint text',
    target,
    is_active: true,
  }));
}

function makeTopicRows(
  count: number,
  category: string,
  subcategory: string,
): SupabaseQuestionRow[] {
  return makeQuestionRows(count, category).map((row, index) => ({
    ...row,
    id: `q_${category}_${subcategory}_${index}`,
    subcategory,
  }));
}

describe('QuestionService', () => {
  let service: QuestionService;
  let mockSelect: jest.Mock;
  let mockEqTarget: jest.Mock;
  let mockEqActive: jest.Mock;
  let mockOrder: jest.Mock;
  let mockRange: jest.Mock;
  let mockFrom: jest.Mock;

  beforeEach(async () => {
    // Build a chained mock through the deterministic paginated query.
    mockRange = jest.fn();
    mockOrder = jest.fn().mockReturnValue({ range: mockRange });
    mockEqActive = jest.fn().mockReturnValue({ order: mockOrder });
    mockEqTarget = jest.fn().mockReturnValue({ eq: mockEqActive });
    mockSelect = jest.fn().mockReturnValue({ eq: mockEqTarget });

    mockFrom = jest.fn().mockReturnValue({ select: mockSelect });
    const mockAdminClient = { from: mockFrom };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QuestionService,
        QuestionDealer,
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

    it('does not backfill a short category from another category', () => {
      const questions = [
        ...makeQuestionRows(2, 'TWK'), // Only 2 TWK available (need 4)
        ...makeQuestionRows(10, 'TIU'),
        ...makeQuestionRows(10, 'TKP'),
      ];

      const pool = service.buildBalancedPool(questions, 12);

      expect(pool).toHaveLength(10);
      expect(
        pool.filter((question) => question.category === 'TWK'),
      ).toHaveLength(2);
      expect(
        pool.filter((question) => question.category === 'TIU'),
      ).toHaveLength(4);
      expect(
        pool.filter((question) => question.category === 'TKP'),
      ).toHaveLength(4);
    });

    it('keeps a category within its quota when other categories are absent', () => {
      const questions = makeQuestionRows(5, 'TWK');

      const pool = service.buildBalancedPool(questions, 12);

      expect(pool).toHaveLength(4);
    });

    it('handles empty question list', () => {
      const pool = service.buildBalancedPool([], 12);
      expect(pool).toHaveLength(0);
    });

    it('keeps CPNS deck categories in the fixed TWK, TIU, TKP order', () => {
      const questions = [
        ...makeQuestionRows(20, 'TWK'),
        ...makeQuestionRows(20, 'TIU'),
        ...makeQuestionRows(20, 'TKP'),
      ];

      const pool = service.buildBalancedPool(questions, 9);

      expect(pool.map((question) => question.category.toUpperCase())).toEqual([
        'TWK',
        'TIU',
        'TKP',
        'TWK',
        'TIU',
        'TKP',
        'TWK',
        'TIU',
        'TKP',
      ]);
    });

    it('keeps BUMN deck categories in a fixed order', () => {
      const questions = [
        ...makeQuestionRows(5, 'AKHLAK', 'bumn'),
        ...makeQuestionRows(5, 'TKD', 'bumn'),
        ...makeQuestionRows(5, 'WAWASAN_KEBANGSAAN', 'bumn'),
      ];

      const pool = service.buildBalancedPool(questions, 6);

      expect(pool.map((question) => question.category.toUpperCase())).toEqual([
        'WAWASAN_KEBANGSAAN',
        'TKD',
        'AKHLAK',
        'WAWASAN_KEBANGSAAN',
        'TKD',
        'AKHLAK',
      ]);
    });

    it('treats BUMN space, underscore, and hyphen aliases as one deck', () => {
      const questions = [
        ...makeQuestionRows(2, 'Wawasan Kebangsaan', 'bumn'),
        ...makeQuestionRows(2, 'WAWASAN_KEBANGSAAN', 'bumn'),
        ...makeQuestionRows(2, 'wawasan-kebangsaan', 'bumn'),
        ...makeQuestionRows(6, 'TKD', 'bumn'),
        ...makeQuestionRows(6, 'AKHLAK', 'bumn'),
      ];

      const pool = service.buildBalancedPool(questions, 9);

      expect(pool).toHaveLength(9);
      expect(
        pool.map((question) =>
          question.category.toUpperCase().replace(/[_-]+/g, ' '),
        ),
      ).toEqual([
        'WAWASAN KEBANGSAAN',
        'TKD',
        'AKHLAK',
        'WAWASAN KEBANGSAAN',
        'TKD',
        'AKHLAK',
        'WAWASAN KEBANGSAAN',
        'TKD',
        'AKHLAK',
      ]);
    });

    it('uses the top-level BUMN category even when a subcategory conflicts', () => {
      const questions = [
        ...makeTopicRows(3, 'WAWASAN_KEBANGSAAN', 'figural'),
        ...makeTopicRows(3, 'TKD', 'figural'),
        ...makeTopicRows(3, 'AKHLAK', 'amanah'),
      ].map((question) => ({ ...question, target: 'bumn' as const }));

      const pool = service.buildBalancedPool(questions, 9);

      expect(pool.map((question) => question.subcategory)).toEqual([
        'figural',
        'figural',
        'amanah',
        'figural',
        'figural',
        'amanah',
        'figural',
        'figural',
        'amanah',
      ]);
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

  describe('buildCpnsRoundPool', () => {
    it('does not reclassify a TIU row as TWK from its subcategory', () => {
      const pool = service.buildCpnsRoundPool([
        ...makeTopicRows(30, 'TIU', 'sejarah_kebangsaan'),
        ...makeTopicRows(35, 'TIU', 'numerik'),
        ...makeTopicRows(45, 'TKP', 'pelayanan_integritas'),
      ]);

      expect(pool).toHaveLength(80);
      expect(
        pool.filter((question) => question.category === 'TIU'),
      ).toHaveLength(35);
      expect(
        pool.filter((question) => question.category === 'TWK'),
      ).toHaveLength(0);
    });

    it('selects the real 30 TWK, 35 TIU, and 45 TKP composition', () => {
      const pool = service.buildCpnsRoundPool([
        ...makeQuestionRows(50, 'TWK'),
        ...makeQuestionRows(50, 'TIU'),
        ...makeQuestionRows(50, 'TKP'),
      ]);

      expect(pool).toHaveLength(110);
      expect(pool.filter((row) => row.category === 'TWK')).toHaveLength(30);
      expect(pool.filter((row) => row.category === 'TIU')).toHaveLength(35);
      expect(pool.filter((row) => row.category === 'TKP')).toHaveLength(45);
    });

    it('does not backfill a short category with a different category', () => {
      const pool = service.buildCpnsRoundPool([
        ...makeQuestionRows(5, 'TWK'),
        ...makeQuestionRows(50, 'TIU'),
        ...makeQuestionRows(50, 'TKP'),
      ]);

      expect(pool.filter((row) => row.category === 'TWK')).toHaveLength(5);
      expect(pool.filter((row) => row.category === 'TIU')).toHaveLength(35);
      expect(pool.filter((row) => row.category === 'TKP')).toHaveLength(45);
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
      mockRange.mockResolvedValue({ data: allRows, error: null });

      const { active, reserve } = await service.getMatchQuestionPoolWithReserve(
        'cpns',
        12,
        12,
      );

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
      mockRange.mockResolvedValue({
        data: null,
        error: { message: 'DB error' },
      });

      await expect(
        service.getMatchQuestionPoolWithReserve('cpns'),
      ).rejects.toThrow('Failed to load question pool');
    });

    it('throws when no questions are found', async () => {
      mockRange.mockResolvedValue({ data: [], error: null });

      await expect(
        service.getMatchQuestionPoolWithReserve('cpns'),
      ).rejects.toThrow('No active questions found');
    });

    it('returns empty reserve when only active cards are requested', async () => {
      const allRows = [
        ...makeQuestionRows(5, 'TWK'),
        ...makeQuestionRows(5, 'TIU'),
        ...makeQuestionRows(5, 'TKP'),
      ];
      mockRange.mockResolvedValue({ data: allRows, error: null });

      const { active, reserve } = await service.getMatchQuestionPoolWithReserve(
        'cpns',
        12,
        0,
      );

      expect(active).toHaveLength(12);
      expect(reserve).toHaveLength(0);
    });
  });

  // ─── getMatchQuestionPool (convenience) ───

  describe('getMatchQuestionPool', () => {
    it('loads the complete CPNS round quotas by default', async () => {
      mockRange.mockResolvedValue({
        data: [
          ...makeQuestionRows(50, 'TWK'),
          ...makeQuestionRows(50, 'TIU'),
          ...makeQuestionRows(50, 'TKP'),
        ],
        error: null,
      });

      const cards = await service.getMatchQuestionPool('cpns');

      expect(cards).toHaveLength(110);
      expect(cards.filter((card) => card.category === 'TWK')).toHaveLength(30);
      expect(cards.filter((card) => card.category === 'TIU')).toHaveLength(35);
      expect(cards.filter((card) => card.category === 'TKP')).toHaveLength(45);
    });

    it('returns only active cards', async () => {
      const allRows = [
        ...makeQuestionRows(10, 'TWK'),
        ...makeQuestionRows(10, 'TIU'),
        ...makeQuestionRows(10, 'TKP'),
      ];
      mockRange.mockResolvedValue({ data: allRows, error: null });

      const cards = await service.getMatchQuestionPool('cpns', 12);

      expect(cards).toHaveLength(12);
      expect(cards[0]).toHaveProperty('correctOptionIndex');
      expect(cards[0]).toHaveProperty('sourceQuestionId');
      expect(mockFrom).toHaveBeenCalledWith('questions');
      expect(mockEqTarget).toHaveBeenCalledWith('target', 'cpns');
      expect(mockEqActive).toHaveBeenCalledWith('is_active', true);
      expect(mockOrder).toHaveBeenCalledWith('id', { ascending: true });
      expect(mockRange).toHaveBeenCalledWith(0, 499);
    });

    it('filters BUMN pools by the requested target', async () => {
      const rows = [
        ...makeQuestionRows(4, 'WAWASAN_KEBANGSAAN', 'bumn'),
        ...makeQuestionRows(4, 'TKD', 'bumn'),
        ...makeQuestionRows(4, 'AKHLAK', 'bumn'),
      ];
      mockRange.mockResolvedValue({ data: rows, error: null });

      const cards = await service.getMatchQuestionPool('bumn', 12);

      expect(cards).toHaveLength(12);
      expect(mockEqTarget).toHaveBeenCalledWith('target', 'bumn');
    });

    it('loads every page so a required category after row 1000 is included', async () => {
      const rows = [
        ...makeQuestionRows(500, 'TIU'),
        ...makeQuestionRows(500, 'TKP'),
        ...makeQuestionRows(200, 'TWK'),
      ];
      mockRange.mockImplementation((from: number, to: number) =>
        Promise.resolve({ data: rows.slice(from, to + 1), error: null }),
      );

      const cards = await service.getMatchQuestionPool('cpns');

      expect(mockRange.mock.calls).toEqual([
        [0, 499],
        [500, 999],
        [1000, 1499],
      ]);
      expect(cards.filter((card) => card.category === 'TWK')).toHaveLength(30);
      expect(cards.filter((card) => card.category === 'TIU')).toHaveLength(35);
      expect(cards.filter((card) => card.category === 'TKP')).toHaveLength(45);
      expect(mockFrom).toHaveBeenCalledTimes(3);
      expect(mockFrom).toHaveBeenCalledWith('questions');
    });

    it('fails closed when a required category is unavailable', async () => {
      mockRange.mockResolvedValue({
        data: [...makeQuestionRows(50, 'TIU'), ...makeQuestionRows(50, 'TKP')],
        error: null,
      });

      await expect(service.getMatchQuestionPool('cpns')).rejects.toThrow(
        'missing one or more required CPNS categories',
      );
    });
  });
});
