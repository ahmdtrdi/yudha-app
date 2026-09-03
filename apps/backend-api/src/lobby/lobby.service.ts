import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { AnalyticsService } from '../analytics/analytics.service';
import { EconomyService } from '../economy/economy.service';
import { ProfileService } from '../profile/profile.service';
import { wibBusinessDate } from '../progression/progression.utils';
import { SupabaseService } from '../supabase/supabase.service';
import { LearningService } from '../learning/learning.service';

const DAILY_MISSIONS = [
  {
    key: 'daily_practice',
    title: 'Selesaikan Practice',
    target: 1,
    rewardYCoins: 0,
  },
  {
    key: 'daily_pvp',
    title: 'Selesaikan PvP publik',
    target: 1,
    rewardYCoins: 0,
  },
] as const;

@Injectable()
export class LobbyService {
  constructor(
    private readonly profileService: ProfileService,
    private readonly analyticsService: AnalyticsService,
    private readonly economyService: EconomyService,
    private readonly supabaseService: SupabaseService,
    private readonly learningService: LearningService,
  ) {}

  async getSummary(userId: string, requestedAt = new Date()) {
    const businessDate = wibBusinessDate(requestedAt);
    const [profile, analytics, economy, missionResult, learningSummary] =
      await Promise.all([
        this.profileService.getProfileData(userId),
        this.analyticsService.getAnalyticsData(userId, requestedAt),
        this.economyService.getState(userId),
        this.supabaseService
          .getClient()
          .from('daily_mission_progress')
          .select('mission_key, completed_at, reward_ycoins')
          .eq('user_id', userId)
          .eq('business_date', businessDate),
        this.learningService.getLobbySummary(userId),
      ]);

    if (missionResult.error) {
      throw new InternalServerErrorException(missionResult.error.message);
    }
    const progress = new Map(
      ((missionResult.data ?? []) as any[]).map((row) => [
        row.mission_key,
        row,
      ]),
    );
    return {
      data: {
        profile,
        tier: profile.tier,
        rankPoints: profile.rankPoints,
        yCoins: profile.yCoins,
        dailyMissions: DAILY_MISSIONS.map((mission) => {
          const completed = progress.get(mission.key) as any;
          return {
            ...mission,
            businessDate,
            progress: completed ? 1 : 0,
            completed: Boolean(completed),
            completedAt: completed?.completed_at ?? null,
          };
        }),
        streak: profile.streak,
        economy: economy.data,
        proSummary: economy.data.pro,
        recommendation: analytics.recommendation,
        learningNextAction: learningSummary.nextAction,
        learningSummary: {
          curriculumCoverage: learningSummary.curriculumCoverage,
        },
      },
    };
  }
}
