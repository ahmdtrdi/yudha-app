import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Json } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';
import type { ActivateProPayload } from './pro.types';

@Injectable()
export class ProService {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly config: ConfigService,
  ) {}

  async getStatus(userId: string) {
    const [{ data: state, error: stateError }, { data: items, error: itemError }] =
      await Promise.all([
        this.supabase.getClient().rpc('get_economy_state', {
          p_user_id: userId,
        }),
        this.supabase
          .getClient()
          .from('store_items')
          .select('id, name, rarity')
          .eq('is_active', true)
          .eq('is_pro_exclusive', true)
          .eq('type', 'character_skin')
          .order('id'),
      ]);
    if (stateError || itemError) {
      throw new InternalServerErrorException(
        stateError?.message ?? itemError?.message,
      );
    }
    const economy = this.object(state, 'get_economy_state');
    return {
      data: {
        plan: {
          id: 'pro-monthly',
          durationDays: 30,
          checkoutEnabled: false,
          disabledCode: 'FEATURE_DISABLED',
          benefits: { unlimitedEnergy: true, monthlyYCoins: 500 },
        },
        entitlement: economy.pro,
        exclusiveSkins: items ?? [],
        betaActivationEnabled: this.betaEnabled(),
      },
    };
  }

  async activateBeta(userId: string, payload: ActivateProPayload) {
    if (!this.betaEnabled()) {
      throw new ForbiddenException(
        'FEATURE_DISABLED: Beta YUDHA Pro activation is disabled.',
      );
    }
    const planId = this.text(payload.planId, 'planId', 80);
    const idempotencyKey = this.text(
      payload.idempotencyKey,
      'idempotencyKey',
      160,
    );
    const skinId =
      payload.skinId == null
        ? null
        : this.text(payload.skinId, 'skinId', 120);
    const { data, error } = await this.supabase.getClient().rpc(
      'activate_pro_beta',
      {
        p_user_id: userId,
        p_plan_id: planId,
        p_skin_id: skinId,
        p_idempotency_key: idempotencyKey,
      },
    );
    if (error) {
      if (
        error.message.includes('PRO_ALREADY_ACTIVE') ||
        error.message.includes('PRO_SKIN_NOT_ELIGIBLE') ||
        error.message.includes('IDEMPOTENCY_KEY_REUSED')
      ) {
        throw new ConflictException(error.message);
      }
      if (error.message.includes('VALIDATION_FAILED')) {
        throw new BadRequestException(error.message);
      }
      throw new InternalServerErrorException(error.message);
    }
    return { data: this.object(data, 'activate_pro_beta') };
  }

  private betaEnabled() {
    return (
      this.config.get<string>('ENABLE_BETA_PRO_ACTIVATION', 'false')
        .trim()
        .toLowerCase() === 'true'
    );
  }

  private text(value: unknown, field: string, maxLength: number) {
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
}
