import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PvpAnalyticsRepository } from './pvp-analytics.repository';
import type {
  PvpAnalyticsMode,
  PvpAnalyticsQuery,
  PvpAnalyticsWindow,
  PvpTopicMetric,
} from './pvp-analytics.types';

@Injectable()
export class PvpAnalyticsService {
  constructor(private readonly repository: PvpAnalyticsRepository) {}

  async getDashboard(
    userId: string,
    query: PvpAnalyticsQuery,
    requestedAt = new Date(),
  ) {
    const window = this.parseWindow(query.window);
    const mode = this.parseMode(query.mode);
    const profile = await this.repository.profile(userId);
    if (!profile) throw new NotFoundException('Profile not found.');
    if (profile.target !== 'cpns' && profile.target !== 'bumn') {
      throw new ConflictException({
        code: 'TARGET_REQUIRED',
        message: 'Choose a learning target before viewing PvP analytics.',
      });
    }
    const target = profile.target as 'cpns' | 'bumn';
    const since = this.windowStart(window, requestedAt);
    const selectedModes = mode === 'all' ? ['ranked', 'casual'] : [mode];
    const coachSince = this.windowStart('30d', requestedAt);

    const [rating, rank, matches, attempts, privateMatches, privateAttempts, events, coachAttempts] =
      await Promise.all([
        this.repository.rating(userId, target),
        this.repository.leaderboardEntry(userId),
        this.repository.matches(userId, target, selectedModes, since),
        this.repository.attempts(userId, target, selectedModes, since),
        this.repository.matches(userId, target, ['private'], since),
        this.repository.attempts(userId, target, ['private'], since),
        this.repository.ratingEvents(userId, target, since),
        this.repository.attempts(
          userId,
          target,
          ['ranked', 'casual'],
          coachSince,
        ),
      ]);

    const invalidated = await this.repository.invalidatedAttemptIds(
      [...attempts, ...privateAttempts, ...coachAttempts].map((row) => row.id),
    );
    const validAttempts = attempts.filter((row) => !invalidated.has(row.id));
    const validPrivateAttempts = privateAttempts.filter(
      (row) => !invalidated.has(row.id),
    );
    const validCoachAttempts = coachAttempts.filter(
      (row) => !invalidated.has(row.id),
    );
    const topics = this.topicMetrics(validAttempts);
    const coachTopics = this.topicMetrics(validCoachAttempts);
    const inventory = await this.repository.inventoryByTopic(
      coachTopics.map((topic) => ({
        taxonomyVersionId: topic.taxonomyVersionId,
        skillId: topic.skillId,
      })),
    );

    return {
      data: {
        asOf: requestedAt.toISOString(),
        target,
        filter: { window, mode, startsAt: since },
        algorithm: { id: 'elo-v1', initialRating: 1000, kFactor: 32 },
        rating: {
          value: Number(rating?.rating ?? 1000),
          rank: rank?.rank == null ? null : Number(rank.rank),
          status: rating?.rated_matches > 0 ? 'rated' : 'unrated',
          changeInWindow: events.reduce(
            (sum, event) => sum + Number(event.rating_delta ?? 0),
            0,
          ),
          ratedMatchCount: Number(rating?.rated_matches ?? 0),
        },
        publicPerformance: this.performance(
          userId,
          matches,
          validAttempts,
        ),
        privatePerformance: this.performance(
          userId,
          privateMatches,
          validPrivateAttempts,
        ),
        modeBreakdown: ['ranked', 'casual'].map((itemMode) => ({
          mode: itemMode,
          ...this.performance(
            userId,
            matches.filter((row) => row.mode === itemMode),
            validAttempts.filter((row) => row.pvp_mode === itemMode),
          ),
        })),
        trend: this.trend(userId, window, matches, validAttempts),
        topicBreakdown: topics,
        evidenceCoverage: this.coverage(validAttempts),
        coach: this.coach(coachTopics, inventory),
        exclusions: {
          bot: 'Bot matches are excluded from competition analytics.',
          private:
            'Private matches are shown separately and never affect rating, rank, or coach.',
        },
      },
    };
  }

  private parseWindow(value?: string): PvpAnalyticsWindow {
    const normalized = value ?? '30d';
    if (normalized === '7d' || normalized === '30d' || normalized === 'all') {
      return normalized;
    }
    throw new BadRequestException('window must be 7d, 30d, or all.');
  }

  private parseMode(value?: string): PvpAnalyticsMode {
    const normalized = value ?? 'all';
    if (
      normalized === 'all' ||
      normalized === 'ranked' ||
      normalized === 'casual'
    ) {
      return normalized;
    }
    throw new BadRequestException('mode must be all, ranked, or casual.');
  }

  private windowStart(
    window: PvpAnalyticsWindow,
    requestedAt: Date,
  ): string | null {
    if (window === 'all') return null;
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Jakarta',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const parts = Object.fromEntries(
      formatter
        .formatToParts(requestedAt)
        .filter((part) => part.type !== 'literal')
        .map((part) => [part.type, Number(part.value)]),
    );
    const days = window === '7d' ? 6 : 29;
    return new Date(
      Date.UTC(parts.year, parts.month - 1, parts.day - days) - 7 * 3600000,
    ).toISOString();
  }

  private performance(userId: string, matches: any[], attempts: any[]) {
    let wins = 0;
    let losses = 0;
    let draws = 0;
    for (const match of matches) {
      if (match.outcome === 'draw' || !match.winner_user_id) draws += 1;
      else if (match.winner_user_id === userId) wins += 1;
      else losses += 1;
    }
    const resolved = attempts.filter((row) => typeof row.is_correct === 'boolean');
    const correct = resolved.filter((row) => row.is_correct === true).length;
    const timedOut = resolved.filter((row) => row.timed_out === true).length;
    const first = resolved.filter((row) => row.seen_before === false);
    const repeat = resolved.filter((row) => row.seen_before === true);
    const times = resolved
      .map((row) =>
        this.numberOrNull(
          row.effective_response_time_ms ?? row.client_active_response_time_ms,
        ),
      )
      .filter((value): value is number => value !== null);
    const questionIds = new Set(
      resolved
        .map((row) => row.question_revision_id ?? row.question_id)
        .filter(Boolean),
    );
    return {
      matches: matches.length,
      wins,
      losses,
      draws,
      winRate: this.ratio(wins, matches.length),
      answers: {
        attempts: resolved.length,
        correct,
        accuracy: this.ratio(correct, resolved.length),
        timedOut,
        timeoutRate: this.ratio(timedOut, resolved.length),
        medianResponseTimeMs: this.median(times),
        uniqueQuestions: questionIds.size,
        exposure: {
          firstEncounter: this.accuracySummary(first),
          repeatEncounter: this.accuracySummary(repeat),
          unknown: resolved.length - first.length - repeat.length,
        },
      },
    };
  }

  private accuracySummary(rows: any[]) {
    const correct = rows.filter((row) => row.is_correct === true).length;
    return {
      attempts: rows.length,
      correct,
      accuracy: this.ratio(correct, rows.length),
    };
  }

  private coverage(attempts: any[]) {
    const broad = attempts.filter((row) => typeof row.is_correct === 'boolean');
    const enriched = broad.filter(
      (row) =>
        row.data_fidelity === 'v2_complete' &&
        row.question_revision_id &&
        row.taxonomy_version_id &&
        row.skill_id,
    );
    return {
      broadAttemptCount: broad.length,
      enrichedAttemptCount: enriched.length,
      legacyAttemptCount: broad.length - enriched.length,
      topicDetailAvailable: enriched.length > 0,
    };
  }

  private topicMetrics(attempts: any[]): PvpTopicMetric[] {
    const groups = new Map<string, any[]>();
    for (const row of attempts) {
      if (
        row.data_fidelity !== 'v2_complete' ||
        !row.question_revision_id ||
        !row.taxonomy_version_id ||
        !row.skill_id ||
        typeof row.is_correct !== 'boolean'
      ) {
        continue;
      }
      const key = `${row.taxonomy_version_id}:${row.skill_id}`;
      groups.set(key, [...(groups.get(key) ?? []), row]);
    }
    const metrics: PvpTopicMetric[] = [];
    for (const [key, rows] of groups) {
      const [taxonomyVersionId, ...skillParts] = key.split(':');
      const skillId = skillParts.join(':');
      const correct = rows.filter((row) => row.is_correct === true).length;
      const attemptsCount = rows.length;
      const uniqueQuestions = new Set(
        rows.map((row) => row.question_revision_id),
      ).size;
      const difficultyCount = new Set(
        rows.map((row) => row.difficulty).filter(Boolean),
      ).size;
      const timedOut = rows.filter((row) => row.timed_out === true).length;
      const smoothedAccuracy = (correct + 2) / (attemptsCount + 4);
      const timeoutRate = timedOut / attemptsCount;
      const times = rows
        .map((row) =>
          this.numberOrNull(
            row.effective_response_time_ms ?? row.client_active_response_time_ms,
          ),
        )
        .filter((value): value is number => value !== null);
      metrics.push({
        taxonomyVersionId,
        skillId,
        category: rows[0].category ?? null,
        subcategory: rows[0].subcategory ?? null,
        attempts: attemptsCount,
        correct,
        uniqueQuestions,
        difficultyCount,
        accuracy: correct / attemptsCount,
        smoothedAccuracy,
        timeoutRate,
        medianResponseTimeMs: this.median(times),
        evidenceStrength:
          attemptsCount >= 15 && uniqueQuestions >= 8 && difficultyCount >= 2
            ? 'high'
            : attemptsCount >= 5 && uniqueQuestions >= 3
              ? 'medium'
              : 'low',
        repairScore: 0.7 * (1 - smoothedAccuracy) + 0.3 * timeoutRate,
      });
    }
    return metrics.sort(
      (a, b) =>
        b.repairScore - a.repairScore ||
        b.attempts - a.attempts ||
        a.skillId.localeCompare(b.skillId),
    );
  }

  private coach(topics: PvpTopicMetric[], inventory: Map<string, number>) {
    const candidate = topics.find((topic) => {
      const available =
        inventory.get(`${topic.taxonomyVersionId}:${topic.skillId}`) ?? 0;
      return (
        topic.attempts >= 5 &&
        topic.uniqueQuestions >= 3 &&
        available >= 5 &&
        (topic.smoothedAccuracy < 0.75 || topic.timeoutRate >= 0.25)
      );
    });
    if (!candidate) return null;
    return {
      objective: 'solo_warmup',
      source: 'pvp_coach',
      basedOnWindow: '30d',
      taxonomyVersionId: candidate.taxonomyVersionId,
      skillId: candidate.skillId,
      category: candidate.category,
      subcategory: candidate.subcategory,
      headline: `Warm-up ${candidate.subcategory ?? candidate.category ?? candidate.skillId}`,
      reason:
        candidate.smoothedAccuracy < 0.75
          ? 'Akurasi kompetitif pada topik ini masih menjadi gap terbesar.'
          : 'Timeout pada topik ini masih sering terjadi.',
      evidence: {
        attempts: candidate.attempts,
        uniqueQuestions: candidate.uniqueQuestions,
        smoothedAccuracy: candidate.smoothedAccuracy,
        timeoutRate: candidate.timeoutRate,
        repairScore: candidate.repairScore,
      },
      soloLaunch: {
        source: 'pvp_coach',
        taxonomyVersionId: candidate.taxonomyVersionId,
        skillId: candidate.skillId,
        category: candidate.category,
        subcategory: candidate.subcategory,
      },
    };
  }

  private trend(userId: string, window: PvpAnalyticsWindow, matches: any[], attempts: any[]) {
    const buckets = new Map<string, { matches: any[]; attempts: any[] }>();
    const bucketFor = (iso: string) => {
      const date = new Date(iso);
      const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Jakarta',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      })
        .formatToParts(date)
        .filter((part) => part.type !== 'literal')
        .reduce<Record<string, string>>((result, part) => {
          result[part.type] = part.value;
          return result;
        }, {});
      return window === 'all'
        ? `${parts.year}-${parts.month}`
        : `${parts.year}-${parts.month}-${parts.day}`;
    };
    for (const match of matches) {
      const key = bucketFor(match.ended_at);
      const bucket = buckets.get(key) ?? { matches: [], attempts: [] };
      bucket.matches.push(match);
      buckets.set(key, bucket);
    }
    for (const attempt of attempts) {
      const key = bucketFor(attempt.source_event_at);
      const bucket = buckets.get(key) ?? { matches: [], attempts: [] };
      bucket.attempts.push(attempt);
      buckets.set(key, bucket);
    }
    return [...buckets.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([period, bucket]) => ({
        period,
        ...this.performance(userId, bucket.matches, bucket.attempts),
      }));
  }

  private ratio(numerator: number, denominator: number): number | null {
    return denominator === 0 ? null : numerator / denominator;
  }

  private numberOrNull(value: unknown): number | null {
    const numeric = Number(value);
    return Number.isFinite(numeric) && numeric >= 0 ? numeric : null;
  }

  private median(values: number[]): number | null {
    if (values.length === 0) return null;
    const sorted = [...values].sort((a, b) => a - b);
    const middle = Math.floor(sorted.length / 2);
    return sorted.length % 2 === 1
      ? sorted[middle]
      : Math.round((sorted[middle - 1] + sorted[middle]) / 2);
  }
}
