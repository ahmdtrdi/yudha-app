import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { AnalyticsService } from '../analytics/analytics.service';
import { HiredPassService } from '../hired-pass/hired-pass.service';
import { ProfileService } from '../profile/profile.service';
import { wibBusinessDate } from '../progression/progression.utils';
import { SupabaseService } from '../supabase/supabase.service';
import { LearningService } from '../learning/learning.service';

const DAILY_MISSIONS = [
  {
    key: 'daily_practice',
    title: 'Selesaikan Practice',
    target: 1,
    rewardYCoins: 2,
  },
  {
    key: 'daily_pvp',
    title: 'Selesaikan PvP publik',
    target: 1,
    rewardYCoins: 1,
  },
] as const;

@Injectable()
export class LobbyService {
  constructor(
    private readonly profileService: ProfileService,
    private readonly analyticsService: AnalyticsService,
    private readonly hiredPassService: HiredPassService,
    private readonly supabaseService: SupabaseService,
    private readonly learningService: LearningService,
  ) {}

  async getSummary(userId: string, requestedAt = new Date()) {
    const businessDate = wibBusinessDate(requestedAt);
    const [profile, analytics, hiredPass, missionResult, learningNextAction] =
      await Promise.all([
        this.profileService.getProfileData(userId),
        this.analyticsService.getAnalyticsData(userId, requestedAt),
        this.hiredPassService.getStatus(userId),
        this.supabaseService
          .getClient()
          .from('daily_mission_progress')
          .select('mission_key, completed_at, reward_ycoins')
          .eq('user_id', userId)
          .eq('business_date', businessDate),
        this.learningService.getLearningNextAction(userId),
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
    const passData: any = hiredPass.data;

    return {
      data: {
        profile,
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
        hiredPassSummary: {
          season: passData.season,
          passPoints: passData.passPoints,
          premiumActive: passData.entitlement.premiumActive,
          expiresAt: passData.entitlement.expiresAt,
          completedMissions: passData.missions.filter(
            (mission: any) => mission.completed,
          ).length,
          totalMissions: passData.missions.length,
          unclaimedRewards: passData.rewards.filter(
            (reward: any) => !passData.claimedRewardIds.includes(reward.id),
          ).length,
        },
        recommendation: analytics.recommendation,
        learningNextAction,
      },
    };
  }
}
