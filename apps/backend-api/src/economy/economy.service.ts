import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import type { Json } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';
import {
  AD_REWARD_VERIFIER,
  type AdRewardVerifier,
  type ClaimAdRewardPayload,
  type PurchaseEnergyPayload,
} from './economy.types';

@Injectable()
export class EconomyService {
  constructor(
    private readonly supabase: SupabaseService,
    @Inject(AD_REWARD_VERIFIER)
    private readonly adVerifier: AdRewardVerifier,
  ) {}

  async getState(userId: string) {
    const { data, error } = await this.supabase.getClient().rpc(
      'get_economy_state',
      { p_user_id: userId },
    );
    if (error) this.throwEconomyError(error.message);
    return { data: this.object(data, 'get_economy_state') };
  }

  async getCatalog() {
    const { data, error } = await this.supabase
      .getClient()
      .from('economy_policy_versions')
      .select('id, policy')
      .eq('is_active', true)
      .single();
    if (error || !data) {
      throw new InternalServerErrorException(
        error?.message ?? 'Active economy policy is unavailable.',
      );
    }
    const policy = this.object(data.policy, 'economy policy');
    return {
      data: {
        policyVersion: data.id,
        balancingStatus: policy.balancingStatus,
        energy: policy.energy,
        paidYCoinPackages: (this.object(policy.yCoin, 'yCoin').paidPackages ?? []),
        paidPurchasesEnabled: false,
        disabledCode: 'FEATURE_DISABLED',
      },
    };
  }

  async purchaseEnergy(userId: string, payload: PurchaseEnergyPayload) {
    const packageId = this.text(payload.packageId, 'packageId', 80);
    const idempotencyKey = this.text(
      payload.idempotencyKey,
      'idempotencyKey',
      160,
    );
    const { data, error } = await this.supabase.getClient().rpc(
      'purchase_energy_pack',
      {
        p_user_id: userId,
        p_package_id: packageId,
        p_idempotency_key: idempotencyKey,
      },
    );
    if (error) this.throwEconomyError(error.message);
    return { data: this.object(data, 'purchase_energy_pack') };
  }

  async claimAdReward(userId: string, payload: ClaimAdRewardPayload) {
    const rewardType = this.rewardType(payload.rewardType);
    const placementId = this.text(payload.placementId, 'placementId', 120);
    const proofToken = this.text(payload.proofToken, 'proofToken', 4096);
    const idempotencyKey = this.text(
      payload.idempotencyKey,
      'idempotencyKey',
      160,
    );
    const verified = await this.adVerifier.verify({
      userId,
      rewardType,
      placementId,
      proofToken,
    });
    const { data, error } = await this.supabase.getClient().rpc(
      'claim_verified_ad_reward',
      {
        p_user_id: userId,
        p_reward_type: rewardType,
        p_placement_id: placementId,
        p_provider: verified.provider,
        p_provider_transaction_id: verified.providerTransactionId,
        p_idempotency_key: idempotencyKey,
      },
    );
    if (error) this.throwEconomyError(error.message);
    return { data: this.object(data, 'claim_verified_ad_reward') };
  }

  private rewardType(value: unknown): 'energy' | 'y_coin' {
    if (value !== 'energy' && value !== 'y_coin') {
      throw new BadRequestException('rewardType must be energy or y_coin.');
    }
    return value;
  }

  private text(value: unknown, field: string, maxLength: number): string {
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

  private object(value: Json | undefined, operation: string) {
    if (!value || Array.isArray(value) || typeof value !== 'object') {
      throw new InternalServerErrorException(
        `${operation} returned an invalid result.`,
      );
    }
    return value as Record<string, any>;
  }

  private throwEconomyError(message: string): never {
    if (
      message.includes('INSUFFICIENT_') ||
      message.includes('ENERGY_CAP_REACHED') ||
      message.includes('AD_REWARD_LIMIT_REACHED') ||
      message.includes('IDEMPOTENCY_KEY_REUSED')
    ) {
      throw new ConflictException(message);
    }
    if (message.includes('VALIDATION_FAILED')) {
      throw new BadRequestException(message);
    }
    throw new InternalServerErrorException(message);
  }
}
