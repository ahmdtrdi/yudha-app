import {
  BadRequestException,
  Injectable,
  NotFoundException,
  InternalServerErrorException,
} from '@nestjs/common';
import type { Json } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';

export type UpdateProfilePayload = Record<string, unknown>;
export type UpdateLoadoutPayload = {
  characterId?: unknown;
  towerId?: unknown;
  arenaId?: unknown;
};

const EDITABLE_PROFILE_FIELDS = new Set(['username', 'full_name', 'target']);
const PROFILE_TARGETS = new Set(['cpns', 'bumn']);

@Injectable()
export class ProfileService {
  constructor(private readonly supabase: SupabaseService) {}

  async getProfile(userId: string) {
    const client = this.supabase.getClient();

    const { data, error } = await client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (error) {
      this.handleProfileReadError(error);
    }

    return data;
  }

  async updateProfile(userId: string, payload: UpdateProfilePayload) {
    const updatePayload = this.cleanUpdatePayload(payload);
    const client = this.supabase.getClient();

    const { data, error } = await client
      .from('profiles')
      .update(updatePayload)
      .eq('id', userId)
      .select('*')
      .single();

    if (error) {
      this.handleProfileReadError(error);
    }

    return data;
  }

  async updateLoadout(userId: string, payload: UpdateLoadoutPayload) {
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('Loadout update payload must be an object.');
    }

    const characterId = this.optionalText(
      payload.characterId,
      'characterId',
      120,
    );
    const towerId = this.optionalText(payload.towerId, 'towerId', 120);
    const arenaId = this.optionalText(payload.arenaId, 'arenaId', 120);
    if (!characterId && !towerId && !arenaId) {
      throw new BadRequestException(
        'At least one loadout field is required.',
      );
    }

    const { data, error } = await this.supabase.getClient().rpc(
      'set_profile_loadout',
      {
        p_user_id: userId,
        p_avatar_id: characterId,
        p_tower_id: towerId,
        p_arena_id: arenaId,
      },
    );

    if (error) {
      const normalized = error.message.toLowerCase();
      if (
        normalized.includes('not owned') ||
        normalized.includes('not available')
      ) {
        throw new BadRequestException(error.message);
      }
      if (normalized.includes('profile not found')) {
        throw new NotFoundException(error.message);
      }
      throw new InternalServerErrorException(error.message);
    }

    return { data: this.requireObject(data) };
  }

  private cleanUpdatePayload(payload: UpdateProfilePayload) {
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('Profile update payload must be an object.');
    }

    const unsupportedFields = Object.keys(payload).filter(
      (field) => !EDITABLE_PROFILE_FIELDS.has(field),
    );
    if (unsupportedFields.length > 0) {
      throw new BadRequestException(
        `Profile fields are not editable: ${unsupportedFields.join(', ')}.`,
      );
    }

    const entries = Object.entries(payload)
      .filter(([, value]) => value !== undefined)
      .map(([field, value]) => [
        field,
        this.validateProfileValue(field, value),
      ]);
    if (entries.length === 0) {
      throw new BadRequestException('At least one profile field is required.');
    }

    return Object.fromEntries(entries);
  }

  private validateProfileValue(field: string, value: unknown) {
    if (field === 'target') {
      const target = this.requiredText(value, field, 20).toLowerCase();
      if (!PROFILE_TARGETS.has(target)) {
        throw new BadRequestException('target must be cpns or bumn.');
      }
      return target;
    }

    if (value === null) {
      return null;
    }
    return this.requiredText(value, field, field === 'username' ? 50 : 120);
  }

  private optionalText(value: unknown, field: string, maxLength: number) {
    if (value === undefined || value === null) {
      return undefined;
    }
    return this.requiredText(value, field, maxLength);
  }

  private requiredText(value: unknown, field: string, maxLength: number) {
    if (typeof value !== 'string' || value.trim() === '') {
      throw new BadRequestException(`${field} must be a non-empty string.`);
    }
    const normalized = value.trim();
    if (normalized.length > maxLength) {
      throw new BadRequestException(
        `${field} must not exceed ${maxLength} characters.`,
      );
    }
    return normalized;
  }

  private requireObject(value: Json) {
    if (!value || Array.isArray(value) || typeof value !== 'object') {
      throw new InternalServerErrorException(
        'set_profile_loadout returned an invalid result.',
      );
    }
    return value;
  }

  private handleProfileReadError(error: { code?: string; message: string }): never {
    if (error.code === 'PGRST116') {
      throw new NotFoundException('Profile not found.');
    }
    throw new InternalServerErrorException(error.message);
  }
}
