import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export type GameEnergyMode = 'bot' | 'casual' | 'ranked' | 'private';

export type EnergyMutationResult = {
  ok: boolean;
  code?: string;
  message?: string;
  data?: Record<string, unknown>;
};

@Injectable()
export class GameEconomyService {
  private readonly logger = new Logger(GameEconomyService.name);

  constructor(private readonly supabase: SupabaseService) {}

  reserve(
    userId: string,
    mode: GameEnergyMode,
    referenceId: string,
    idempotencyKey: string,
    ttlSeconds = 900,
  ) {
    return this.rpc('reserve_energy', {
      p_user_id: userId,
      p_mode: mode,
      p_reference_id: referenceId,
      p_idempotency_key: idempotencyKey,
      p_ttl_seconds: ttlSeconds,
      p_commit_immediately: false,
    });
  }

  commit(userId: string, mode: GameEnergyMode, referenceId?: string) {
    return this.rpc('commit_energy_reservation', {
      p_user_id: userId,
      p_mode: mode,
      p_reference_id: referenceId ?? null,
    });
  }

  release(
    userId: string,
    mode: GameEnergyMode,
    reason: string,
    referenceId?: string,
  ) {
    return this.rpc('release_energy_reservation', {
      p_user_id: userId,
      p_mode: mode,
      p_reason: reason,
      p_reference_id: referenceId ?? null,
    });
  }

  releaseExpired() {
    return this.rpc('release_expired_energy_reservations', { p_limit: 200 });
  }

  private async rpc(
    name: string,
    parameters: Record<string, unknown>,
  ): Promise<EnergyMutationResult> {
    try {
      const { data, error } = await this.supabase
        .getAdminClient()
        .rpc(name, parameters);
      if (error) {
        const code = this.code(error.message);
        this.logger.warn(`ENERGY_MUTATION_FAILED operation=${name} code=${code}`);
        return { ok: false, code, message: error.message };
      }
      return {
        ok: true,
        data:
          data && typeof data === 'object' && !Array.isArray(data)
            ? (data as Record<string, unknown>)
            : { result: data as unknown },
      };
    } catch (error) {
      this.logger.error(
        `ENERGY_MUTATION_FAILED operation=${name} error=${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return {
        ok: false,
        code: 'QUEUE_UNAVAILABLE',
        message: 'Energy service is unavailable.',
      };
    }
  }

  private code(message: string) {
    if (message.includes('INSUFFICIENT_ENERGY')) return 'INSUFFICIENT_ENERGY';
    if (message.includes('IDEMPOTENCY_KEY_REUSED')) {
      return 'IDEMPOTENCY_KEY_REUSED';
    }
    return 'QUEUE_UNAVAILABLE';
  }
}
