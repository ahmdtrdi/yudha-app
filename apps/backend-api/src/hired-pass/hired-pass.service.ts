import {
  BadRequestException,
  ConflictException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import type { Database, Json } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class HiredPassService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getStatus(userId: string) {
    const client = this.supabaseService.getClient();
    const now = new Date();
    const nowIso = now.toISOString();
    const { data: season, error: seasonError } = await client
      .from('hired_pass_seasons')
      .select('*')
      .eq('is_active', true)
      .lte('starts_at', nowIso)
      .gt('ends_at', nowIso)
      .order('starts_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (seasonError) {
      throw new InternalServerErrorException(seasonError.message);
    }
    if (!season) {
      return {
        data: {
          season: null,
          passPoints: 0,
          entitlement: { premiumActive: false, expiresAt: null },
          adFree: false,
          missions: [],
          rewards: [],
          claimedRewardIds: [],
        },
      };
    }

    const [profileResult, progressResult, missionsResult, rewardsResult] =
      await Promise.all([
        client
          .from('profiles')
          .select('hired_pass_expires_at')
          .eq('id', userId)
          .single(),
        client
          .from('user_hired_pass_progress')
          .select('pass_points')
          .eq('user_id', userId)
          .eq('season_id', season.id)
          .maybeSingle(),
        client
          .from('hired_pass_missions')
          .select('*')
          .eq('season_id', season.id)
          .eq('is_active', true)
          .order('created_at'),
        client
          .from('hired_pass_rewards')
          .select('*')
          .eq('season_id', season.id)
          .eq('is_active', true)
          .order('points_required')
          .order('track'),
      ]);

    const baseError =
      profileResult.error ??
      progressResult.error ??
      missionsResult.error ??
      rewardsResult.error;
    if (baseError) {
      throw new InternalServerErrorException(baseError.message);
    }
    if (!profileResult.data) {
      throw new NotFoundException('Profile not found.');
    }

    const missionIds = (missionsResult.data ?? []).map(
      (mission) => mission.id,
    );
    const rewardIds = (rewardsResult.data ?? []).map((reward) => reward.id);
    let missionProgress: Database['public']['Tables']['user_hired_pass_mission_progress']['Row'][] =
      [];
    if (missionIds.length > 0) {
      const { data, error } = await client
        .from('user_hired_pass_mission_progress')
        .select('*')
        .eq('user_id', userId)
        .in('mission_id', missionIds);
      if (error) {
        throw new InternalServerErrorException(error.message);
      }
      missionProgress = data ?? [];
    }

    let claimedRewardIds: string[] = [];
    if (rewardIds.length > 0) {
      const { data, error } = await client
        .from('user_hired_pass_reward_claims')
        .select('reward_id')
        .eq('user_id', userId)
        .in('reward_id', rewardIds);
      if (error) {
        throw new InternalServerErrorException(error.message);
      }
      claimedRewardIds = (data ?? []).map((claim) => claim.reward_id);
    }

    const expiresAt = profileResult.data.hired_pass_expires_at;
    const premiumActive =
      expiresAt !== null && new Date(expiresAt).getTime() > now.getTime();

    return {
      data: {
        season: {
          id: season.id,
          name: season.name,
          startsAt: season.starts_at,
          endsAt: season.ends_at,
        },
        passPoints: progressResult.data?.pass_points ?? 0,
        entitlement: { premiumActive, expiresAt },
        adFree: premiumActive,
        missions: (missionsResult.data ?? []).map((mission) => {
          const periodStart = this.periodStart(
            mission.cadence,
            now,
            season.starts_at,
          );
          const progress = missionProgress.find(
            (entry) =>
              entry.mission_id === mission.id &&
              entry.period_start === periodStart,
          );
          return {
            id: mission.id,
            title: mission.title,
            description: mission.description,
            cadence: mission.cadence,
            progress: progress?.progress_count ?? 0,
            target: mission.target_count,
            passPointsReward: mission.points_reward,
            completed: progress?.points_awarded_at != null,
            periodStart,
          };
        }),
        rewards: (rewardsResult.data ?? []).map((reward) => ({
          id: reward.id,
          track: reward.track,
          pointsRequired: reward.points_required,
          label: reward.label,
          coins: reward.coins_reward,
          itemId: reward.item_id,
        })),
        claimedRewardIds,
      },
    };
  }

  async claimReward(userId: string, rewardIdValue: unknown) {
    const rewardId = this.requiredText(rewardIdValue, 'rewardId', 120);
    const { data, error } = await this.supabaseService
      .getClient()
      .rpc('claim_hired_pass_reward', {
        p_user_id: userId,
        p_reward_id: rewardId,
      });

    if (error) {
      this.throwClaimError(error.message);
    }

    const result = this.requireObject(data);
    if (result.claimed === false && result.reason === 'already_claimed') {
      throw new ConflictException('Hired Pass reward is already claimed.');
    }

    return { data: result };
  }

  private periodStart(
    cadence: string,
    now: Date,
    seasonStartsAt: string,
  ): string {
    if (cadence === 'season') {
      return seasonStartsAt.slice(0, 10);
    }

    const date = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
    );
    if (cadence === 'weekly') {
      const daysSinceMonday = (date.getUTCDay() + 6) % 7;
      date.setUTCDate(date.getUTCDate() - daysSinceMonday);
    }
    return date.toISOString().slice(0, 10);
  }

  private requiredText(value: unknown, field: string, maxLength: number) {
    if (typeof value !== 'string' || value.trim() === '') {
      throw new BadRequestException(`${field} is required.`);
    }
    const normalized = value.trim();
    if (normalized.length > maxLength) {
      throw new BadRequestException(
        `${field} must not exceed ${maxLength} characters.`,
      );
    }
    return normalized;
  }

  private requireObject(value: Json): Record<string, Json | undefined> {
    if (!value || Array.isArray(value) || typeof value !== 'object') {
      throw new InternalServerErrorException(
        'claim_hired_pass_reward returned an invalid result.',
      );
    }
    return value;
  }

  private throwClaimError(message: string): never {
    const normalized = message.toLowerCase();
    if (normalized.includes('not available')) {
      throw new NotFoundException(message);
    }
    if (
      normalized.includes('not enough') ||
      normalized.includes('entitlement')
    ) {
      throw new BadRequestException(message);
    }
    throw new InternalServerErrorException(message);
  }
}
