import { buildRecommendation, recommendationWindow } from './analytics.service';
import type { AnswerObservation, TopicMetric } from './analytics.types';

const NOW = new Date('2026-08-17T05:00:00.000Z');

describe('Gate 1 deterministic recommendation', () => {
  it('recommends general Practice below five answers', () => {
    const result = recommend({ answers: answers(4) });
    expect(result).toMatchObject({ type: 'practice', target: 'cpns' });
    expect(result).not.toHaveProperty('category');
  });

  it('selects the deterministic weakest qualifying subcategory', () => {
    const result = recommend({
      answers: answers(12),
      subcategories: [
        topic('tiu', 'verbal', 60, 5, '2026-08-14T00:00:00Z'),
        topic('tiu', 'numerik', 60, 7, '2026-08-15T00:00:00Z'),
      ],
    });
    expect(result).toMatchObject({
      type: 'practice',
      category: 'tiu',
      subcategory: 'numerik',
      metrics: { sampleSize: 7, accuracy: 60 },
    });
  });

  it('selects a weak category when no subcategory qualifies', () => {
    const result = recommend({
      answers: answers(10),
      categories: [topic('twk', null, 70, 10, '2026-08-16T00:00:00Z')],
    });
    expect(result).toMatchObject({
      type: 'practice',
      category: 'twk',
      metrics: { sampleSize: 10, accuracy: 70 },
    });
  });

  it('recommends Interview when none completed since the sixth prior WIB date', () => {
    const result = recommend({
      answers: answers(10),
      categories: [topic('tiu', null, 90, 10, '2026-08-16T00:00:00Z')],
      lastInterviewCompletedAt: '2026-08-10T16:59:59.999Z',
    });
    expect(result).toMatchObject({ type: 'interview' });
  });

  it('falls back to the never-practiced category after a recent Interview', () => {
    const result = recommend({
      answers: answers(10),
      categories: [topic('tiu', null, 90, 10, '2026-08-16T00:00:00Z')],
      activeCategories: ['tiu', 'twk'],
      lastInterviewCompletedAt: '2026-08-11T00:00:00.000Z',
    });
    expect(result).toMatchObject({
      type: 'practice',
      category: 'twk',
      metrics: { sampleSize: 0, accuracy: null, lastPracticedAt: null },
    });
  });

  it('includes the current and preceding 89 WIB dates exactly', () => {
    expect(recommendationWindow(NOW)).toEqual({
      businessDays: 90,
      startsAt: '2026-05-19T17:00:00.000Z',
      endsAt: '2026-08-17T05:00:00.000Z',
    });
  });
});

function recommend(overrides: {
  answers?: AnswerObservation[];
  categories?: TopicMetric[];
  subcategories?: TopicMetric[];
  activeCategories?: string[];
  lastInterviewCompletedAt?: string | null;
}) {
  return buildRecommendation({
    target: 'cpns',
    answers: overrides.answers ?? answers(10),
    categories: overrides.categories ?? [],
    subcategories: overrides.subcategories ?? [],
    activeCategories: overrides.activeCategories ?? ['tiu'],
    lastInterviewCompletedAt:
      overrides.lastInterviewCompletedAt === undefined
        ? '2026-08-16T00:00:00.000Z'
        : overrides.lastInterviewCompletedAt,
    requestedAt: NOW,
  });
}

function answers(count: number): AnswerObservation[] {
  return Array.from({ length: count }, (_, index) => ({
    target: 'cpns',
    category: 'tiu',
    subcategory: 'verbal',
    isCorrect: true,
    responseTimeMs: 1000,
    answeredAt: new Date(NOW.getTime() - index * 1000).toISOString(),
    source: index % 2 === 0 ? 'practice' : 'ranked',
  }));
}

function topic(
  category: string,
  subcategory: string | null,
  accuracy: number,
  sampleSize: number,
  lastPracticedAt: string | null,
): TopicMetric {
  return {
    target: 'cpns',
    category,
    subcategory,
    accuracy,
    sampleSize,
    averageResponseTimeMs: 1000,
    lastPracticedAt,
  };
}
