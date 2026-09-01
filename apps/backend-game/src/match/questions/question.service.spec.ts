import { Test, TestingModule } from '@nestjs/testing';
import { QuestionService } from './question.service';
import { SupabaseService } from '../../supabase/supabase.service';
import { QuestionDealer } from '../engine/question-dealer';
import type { SupabaseQuestionRow } from './question.types';

/** Create stub question rows resembling Supabase data */
function makeQuestionRows(
  count: number,
  category: string = 'TWK',
): SupabaseQuestionRow[] {
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
    effect: i % 2 === 0 ? 'damage' : 'heal',
    damage_value: i % 2 === 0 ? 14 : 0,
    heal_value: i % 2 === 0 ? 0 : 14,
    time_limit_seconds: 30,
    hint: 'Hint text',
    target: 'cpns' as const,
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
  let mockFrom: jest.Mock;

  beforeEach(async () => {
    // Build a chained mock: .from().select().eq('target').eq('is_active')
    mockEqActive = jest.fn();
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

    it('backfills from other categories when one is short', () => {
      const questions = [
        ...makeQuestionRows(2, 'TWK'), // Only 2 TWK available (need 4)
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
        ...makeQuestionRows(5, 'AKHLAK'),
        ...makeQuestionRows(5, 'TKD'),
        ...makeQuestionRows(5, 'WAWASAN_KEBANGSAAN'),
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
      mockEqActive.mockResolvedValue({ data: allRows, error: null });

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
      mockEqActive.mockResolvedValue({
        data: null,
        error: { message: 'DB error' },
      });

      await expect(
        service.getMatchQuestionPoolWithReserve('cpns'),
      ).rejects.toThrow('Failed to load question pool');
    });

    it('throws when no questions are found', async () => {
      mockEqActive.mockResolvedValue({ data: [], error: null });

      await expect(
        service.getMatchQuestionPoolWithReserve('cpns'),
      ).rejects.toThrow('No active questions found');
    });

    it('returns empty reserve when only active cards are requested', async () => {
      const allRows = makeQuestionRows(15, 'TWK');
      mockEqActive.mockResolvedValue({ data: allRows, error: null });

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
      mockEqActive.mockResolvedValue({
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
      mockEqActive.mockResolvedValue({ data: allRows, error: null });

      const cards = await service.getMatchQuestionPool('cpns', 12);

      expect(cards).toHaveLength(12);
      expect(cards[0]).toHaveProperty('correctOptionIndex');
      expect(cards[0]).toHaveProperty('sourceQuestionId');
      expect(mockFrom).toHaveBeenCalledWith('questions');
      expect(mockEqTarget).toHaveBeenCalledWith('target', 'cpns');
      expect(mockEqActive).toHaveBeenCalledWith('is_active', true);
    });

    it('filters BUMN pools by the requested target', async () => {
      const rows = makeQuestionRows(12, 'AKHLAK').map((row) => ({
        ...row,
        target: 'bumn' as const,
      }));
      mockEqActive.mockResolvedValue({ data: rows, error: null });

      const cards = await service.getMatchQuestionPool('bumn', 12);

      expect(cards).toHaveLength(12);
      expect(mockEqTarget).toHaveBeenCalledWith('target', 'bumn');
    });

    it('loads two active topics and applies their averaged PvP mix', async () => {
      const rows = [
        ...[
          'pancasila_dan_ideologi',
          'konstitusi_dan_negara',
          'sejarah_dan_kebangsaan',
          'bhinneka_tunggal_ika',
        ].flatMap((subcategory) => makeTopicRows(50, 'TWK', subcategory)),
        ...['verbal', 'numerik', 'logis', 'figural'].flatMap((subcategory) =>
          makeTopicRows(50, 'TIU', subcategory),
        ),
        ...[
          'pelayanan_dan_integritas',
          'kerja_sama_dan_komunikasi',
          'adaptasi_dan_pengembangan_diri',
          'pengambilan_keputusan_dan_kinerja',
        ].flatMap((subcategory) => makeTopicRows(50, 'TKP', subcategory)),
      ];
      const questionEqActive = jest.fn().mockResolvedValue({
        data: rows,
        error: null,
      });
      const questionEqTarget = jest
        .fn()
        .mockReturnValue({ eq: questionEqActive });
      const recommendationGt = jest.fn().mockResolvedValue({
        data: [
          {
            user_id: 'player-a',
            target: 'cpns',
            skill_ids: ['cpns.tiu.numerik'],
          },
          {
            user_id: 'player-b',
            target: 'cpns',
            skill_ids: ['cpns.tiu.numerik'],
          },
        ],
        error: null,
      });
      const recommendationSelection = jest
        .fn()
        .mockReturnValue({ gt: recommendationGt });
      const recommendationAvailability = jest
        .fn()
        .mockReturnValue({ eq: recommendationSelection });
      const recommendationStatus = jest
        .fn()
        .mockReturnValue({ eq: recommendationAvailability });
      const recommendationTarget = jest
        .fn()
        .mockReturnValue({ eq: recommendationStatus });
      const recommendationIn = jest
        .fn()
        .mockReturnValue({ eq: recommendationTarget });
      const adminClient = {
        from: jest.fn((table: string) =>
          table === 'questions'
            ? {
                select: jest.fn().mockReturnValue({ eq: questionEqTarget }),
              }
            : {
                select: jest.fn().mockReturnValue({ in: recommendationIn }),
              },
        ),
      };
      const adaptiveService = new QuestionService(
        {
          getAdminClient: () => adminClient,
        } as unknown as SupabaseService,
        new QuestionDealer(),
      );

      const cards = await adaptiveService.getMatchQuestionPool(
        'cpns',
        undefined,
        ['player-a', 'player-b'],
      );
      const tiuCards = cards.filter((card) => card.category === 'TIU');

      expect(recommendationIn).toHaveBeenCalledWith('user_id', [
        'player-a',
        'player-b',
      ]);
      expect(tiuCards).toHaveLength(35);
      expect(
        tiuCards.filter((card) => card.subcategory === 'numerik').length,
      ).toBeGreaterThanOrEqual(19);
      expect(
        tiuCards.filter((card) => card.subcategory === 'verbal').length,
      ).toBeLessThanOrEqual(6);
    });
  });
});
