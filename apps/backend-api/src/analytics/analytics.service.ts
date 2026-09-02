import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import type {
  AnswerObservation,
  LearningAnalytics,
  LearningRecommendation,
  TopicMetric,
} from './analytics.types';

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const HISTORY_LIMIT = 20;

type RawAnswer = {
  is_correct: boolean | null;
  response_time_ms: number | null;
  answered_at?: string;
  action_timestamp?: string;
  questions: {
    target: string;
    category: string;
    subcategory: string | null;
  } | null;
};

@Injectable()
export class AnalyticsService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getPerformanceAnalytics(userId: string) {
    return { data: await this.getAnalyticsData(userId) };
  }

  async getAnalyticsData(
    userId: string,
    requestedAt = new Date(),
  ): Promise<LearningAnalytics> {
    const client = this.supabaseService.getClient() as any;
    const window = recommendationWindow(requestedAt);

    const profileResult = await client
      .from('profiles')
      .select(
        'target, wins, losses, draws, current_streak, best_streak, last_streak_date',
      )
      .eq('id', userId)
      .single();

    if (profileResult.error || !profileResult.data) {
      throw new InternalServerErrorException(
        profileResult.error?.message ?? 'Profile not found for analytics.',
      );
    }

    const target = String(profileResult.data.target);
    const results = await Promise.all([
      client
        .from('practice_answers')
        .select(
          'is_correct, response_time_ms, answered_at, questions!inner(target, category, subcategory)',
        )
        .eq('user_id', userId)
        .eq('questions.target', target)
        .not('question_id', 'is', null)
        .gte('answered_at', window.startsAt)
        .lte('answered_at', window.endsAt),
      client
        .from('match_logs')
        .select(
          'is_correct, response_time_ms, action_timestamp, questions!inner(target, category, subcategory), match_results!inner(mode)',
        )
        .eq('player_id', userId)
        .eq('questions.target', target)
        .eq('match_results.mode', 'ranked')
        .not('is_correct', 'is', null)
        .gte('action_timestamp', window.startsAt)
        .lte('action_timestamp', window.endsAt),
      client
        .from('practice_sessions')
        .select(
          'id, category, subcategory, correct_count, total_questions, accuracy, finished_at',
        )
        .eq('user_id', userId)
        .not('finished_at', 'is', null)
        .order('finished_at', { ascending: false })
        .limit(HISTORY_LIMIT),
      client
        .from('pvp_rating_events')
        .select('match_result_id, rating_delta, rating_after, created_at')
        .eq('user_id', userId)
        .eq('target', target)
        .eq('algorithm_version', 'elo-v1')
        .order('created_at', { ascending: false })
        .limit(HISTORY_LIMIT),
      client
        .from('interview_sessions')
        .select('updated_at')
        .eq('user_id', userId)
        .eq('status', 'completed')
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle(),
      client
        .from('questions')
        .select('target, category')
        .eq('target', target)
        .eq('is_active', true),
      client
        .from('match_results')
        .select('winner_user_id, outcome, mode, reason, ended_at')
        .in('mode', ['casual', 'ranked'])
        .or(`player_a_id.eq.${userId},player_b_id.eq.${userId}`),
    ]);

    const failed = results.find((result) => result.error);
    if (failed?.error) {
      throw new InternalServerErrorException(failed.error.message);
    }

    const practiceAnswers = mapAnswers(
      (results[0].data ?? []) as RawAnswer[],
      'practice',
    );
    const rankedAnswers = mapAnswers(
      (results[1].data ?? []) as RawAnswer[],
      'ranked',
    );
    // Compatibility analytics must not let competition evidence change the
    // user's Solo recommendation.
    const allAnswers = practiceAnswers;
    const categoryBreakdown = aggregateTopics(practiceAnswers, false);
    const subcategoryBreakdown = aggregateTopics(practiceAnswers, true);
    const recommendationTopics = {
      categories: aggregateTopics(allAnswers, false),
      subcategories: aggregateTopics(allAnswers, true),
    };
    const activeCategories = Array.from(
      new Set<string>(
        ((results[5].data ?? []) as { category: string }[]).map(
          (row) => row.category,
        ),
      ),
    ).sort();
    const latestInterview = results[4].data?.updated_at ?? null;
    const recommendation = buildRecommendation({
      target,
      answers: allAnswers,
      categories: recommendationTopics.categories,
      subcategories: recommendationTopics.subcategories,
      activeCategories,
      lastInterviewCompletedAt: latestInterview,
      requestedAt,
    });
    const publicMatches = publicMatchStats(results[6].data ?? [], userId);

    return {
      window,
      practice: {
        ...answerSummary(practiceAnswers),
        categoryBreakdown,
        subcategoryBreakdown,
      },
      ranked: answerSummary(rankedAnswers),
      weakTopics: [
        ...recommendationTopics.subcategories.filter(
          (topic) => topic.sampleSize >= 5 && topic.accuracy < 70,
        ),
        ...recommendationTopics.categories.filter(
          (topic) => topic.sampleSize >= 10 && topic.accuracy < 80,
        ),
      ].sort(compareWeakTopics),
      publicMatches,
      streak: {
        current: Number(profileResult.data.current_streak ?? 0),
        best: Number(profileResult.data.best_streak ?? 0),
        lastDate: profileResult.data.last_streak_date ?? null,
      },
      history: {
        practice: results[2].data ?? [],
        ranked: results[3].data ?? [],
      },
      recommendation,
    };
  }
}

export function buildRecommendation(input: {
  target: string;
  answers: AnswerObservation[];
  categories: TopicMetric[];
  subcategories: TopicMetric[];
  activeCategories: string[];
  lastInterviewCompletedAt: string | null;
  requestedAt: Date;
}): LearningRecommendation {
  if (input.answers.length < 5) {
    return {
      type: 'practice',
      target: input.target,
      reason:
        'Kerjakan latihan umum agar YUDHA memiliki cukup data untuk rekomendasi yang lebih spesifik.',
      metrics: {
        sampleSize: input.answers.length,
        accuracy: accuracy(input.answers),
        lastPracticedAt: latestAnswer(input.answers),
      },
    };
  }

  const weakSubcategory = input.subcategories
    .filter((topic) => topic.sampleSize >= 5 && topic.accuracy < 70)
    .sort(compareWeakTopics)[0];
  if (weakSubcategory) {
    return practiceRecommendation(
      input.target,
      weakSubcategory,
      `Perkuat ${weakSubcategory.subcategory} karena akurasinya masih di bawah 70%.`,
    );
  }

  const weakCategory = input.categories
    .filter((topic) => topic.sampleSize >= 10 && topic.accuracy < 80)
    .sort(compareWeakTopics)[0];
  if (weakCategory) {
    return practiceRecommendation(
      input.target,
      weakCategory,
      `Perkuat ${weakCategory.category} karena akurasinya masih di bawah 80%.`,
    );
  }

  const interviewCutoff = startOfWibDate(addWibDays(input.requestedAt, -6));
  if (
    !input.lastInterviewCompletedAt ||
    new Date(input.lastInterviewCompletedAt).getTime() <
      interviewCutoff.getTime()
  ) {
    return {
      type: 'interview',
      reason:
        'Jadwalkan simulasi wawancara untuk melatih jawaban dan komunikasi minggu ini.',
      lastCompletedAt: input.lastInterviewCompletedAt,
    };
  }

  const categoryById = new Map(
    input.categories.map((topic) => [topic.category, topic]),
  );
  const leastRecent = input.activeCategories
    .map(
      (category) =>
        categoryById.get(category) ?? {
          target: input.target,
          category,
          subcategory: null,
          accuracy: 0,
          sampleSize: 0,
          averageResponseTimeMs: 0,
          lastPracticedAt: null,
        },
    )
    .sort(compareLeastRecent)[0];

  return practiceRecommendation(
    input.target,
    leastRecent ?? {
      target: input.target,
      category: '',
      subcategory: null,
      accuracy: 0,
      sampleSize: input.answers.length,
      averageResponseTimeMs: 0,
      lastPracticedAt: latestAnswer(input.answers),
    },
    'Latih kembali topik yang paling lama tidak dipraktikkan agar kemampuan tetap merata.',
  );
}

export function aggregateTopics(
  answers: AnswerObservation[],
  bySubcategory: boolean,
): TopicMetric[] {
  const groups = new Map<string, AnswerObservation[]>();
  for (const answer of answers) {
    if (bySubcategory && !answer.subcategory) continue;
    const key = bySubcategory
      ? `${answer.target}\u0000${answer.category}\u0000${answer.subcategory}`
      : `${answer.target}\u0000${answer.category}`;
    const values = groups.get(key) ?? [];
    values.push(answer);
    groups.set(key, values);
  }

  return Array.from(groups.values()).map((values) => ({
    target: values[0].target,
    category: values[0].category,
    subcategory: bySubcategory ? values[0].subcategory : null,
    accuracy: accuracy(values) ?? 0,
    sampleSize: values.length,
    averageResponseTimeMs: averageResponseTime(values),
    lastPracticedAt: latestAnswer(values),
  }));
}

function mapAnswers(
  rows: RawAnswer[],
  source: 'practice' | 'ranked',
): AnswerObservation[] {
  return rows
    .filter((row) => row.questions && row.is_correct !== null)
    .map((row) => ({
      target: row.questions!.target,
      category: row.questions!.category,
      subcategory: row.questions!.subcategory,
      isCorrect: Boolean(row.is_correct),
      responseTimeMs: row.response_time_ms,
      answeredAt: String(row.answered_at ?? row.action_timestamp),
      source,
    }));
}

function answerSummary(answers: AnswerObservation[]) {
  return {
    accuracy: accuracy(answers) ?? 0,
    averageResponseTimeMs: averageResponseTime(answers),
    sampleSize: answers.length,
  };
}

function accuracy(answers: AnswerObservation[]): number | null {
  if (answers.length === 0) return null;
  const correct = answers.filter((answer) => answer.isCorrect).length;
  return Number(((correct / answers.length) * 100).toFixed(2));
}

function averageResponseTime(answers: AnswerObservation[]): number {
  const measured = answers
    .map((answer) => answer.responseTimeMs)
    .filter((value): value is number => value !== null && value >= 0);
  if (measured.length === 0) return 0;
  return Math.round(
    measured.reduce((sum, value) => sum + value, 0) / measured.length,
  );
}

function latestAnswer(answers: AnswerObservation[]): string | null {
  if (answers.length === 0) return null;
  return answers.reduce(
    (latest, answer) =>
      answer.answeredAt > latest ? answer.answeredAt : latest,
    answers[0].answeredAt,
  );
}

function practiceRecommendation(
  target: string,
  topic: TopicMetric,
  reason: string,
): LearningRecommendation {
  return {
    type: 'practice',
    target,
    ...(topic.category ? { category: topic.category } : {}),
    ...(topic.subcategory ? { subcategory: topic.subcategory } : {}),
    reason,
    metrics: {
      sampleSize: topic.sampleSize,
      accuracy: topic.sampleSize > 0 ? topic.accuracy : null,
      lastPracticedAt: topic.lastPracticedAt,
    },
  };
}

function compareWeakTopics(a: TopicMetric, b: TopicMetric): number {
  return (
    a.accuracy - b.accuracy ||
    b.sampleSize - a.sampleSize ||
    compareNullableDates(a.lastPracticedAt, b.lastPracticedAt) ||
    stableTopicId(a).localeCompare(stableTopicId(b))
  );
}

function compareLeastRecent(a: TopicMetric, b: TopicMetric): number {
  return (
    compareNullableDates(a.lastPracticedAt, b.lastPracticedAt) ||
    a.category.localeCompare(b.category)
  );
}

function compareNullableDates(a: string | null, b: string | null): number {
  if (a === null && b === null) return 0;
  if (a === null) return -1;
  if (b === null) return 1;
  return new Date(a).getTime() - new Date(b).getTime();
}

function stableTopicId(topic: TopicMetric): string {
  return `${topic.target}:${topic.category}:${topic.subcategory ?? ''}`;
}

function publicMatchStats(rows: any[], userId: string) {
  const wins = rows.filter((row) => row.winner_user_id === userId).length;
  const draws = rows.filter((row) => row.outcome === 'draw').length;
  const losses = rows.length - wins - draws;
  const sampleSize = wins + losses + draws;
  return {
    wins,
    losses,
    draws,
    sampleSize,
    winRate:
      sampleSize === 0 ? 0 : Number(((wins / sampleSize) * 100).toFixed(2)),
  };
}

export function recommendationWindow(
  requestedAt: Date,
): LearningAnalytics['window'] {
  const startsAt = startOfWibDate(addWibDays(requestedAt, -89));
  return {
    businessDays: 90,
    startsAt: startsAt.toISOString(),
    endsAt: requestedAt.toISOString(),
  };
}

function addWibDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function startOfWibDate(date: Date): Date {
  const wib = new Date(date.getTime() + WIB_OFFSET_MS);
  return new Date(
    Date.UTC(wib.getUTCFullYear(), wib.getUTCMonth(), wib.getUTCDate()) -
      WIB_OFFSET_MS,
  );
}
