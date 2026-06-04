import {
  BadRequestException,
  Injectable,
  NotFoundException,
  InternalServerErrorException,
} from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export type UpdateProfilePayload = Record<string, unknown>;

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

  private cleanUpdatePayload(payload: UpdateProfilePayload) {
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('Profile update payload must be an object.');
    }

    const entries = Object.entries(payload).filter(([, value]) => value !== undefined);
    if (entries.length === 0) {
      throw new BadRequestException('At least one profile field is required.');
    }

    return Object.fromEntries(entries);
  }

  private handleProfileReadError(error: { code?: string; message: string }): never {
    if (error.code === 'PGRST116') {
      throw new NotFoundException('Profile not found.');
    }
    throw new InternalServerErrorException(error.message);
  }
}
