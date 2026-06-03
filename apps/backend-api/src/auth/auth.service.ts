import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export type RegisterPayload = {
  email?: string;
  password?: string;
  username?: string;
  fullName?: string;
};

export type LoginPayload = {
  email?: string;
  password?: string;
};

@Injectable()
export class AuthService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async register(payload: RegisterPayload) {
    const email = this.requireEmail(payload.email);
    const password = this.requirePassword(payload.password);

    const supabase = this.supabaseService.getClient();
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          username: payload.username?.trim() || email.split('@')[0],
          full_name: payload.fullName?.trim() || null,
        },
      },
    });

    if (error) throw new BadRequestException(error.message);

    return {
      user: data.user,
      session: data.session,
      message: data.session
        ? 'Registration successful.'
        : 'Registration successful. Please confirm the email before login if confirmation is enabled.',
    };
  }

  async login(payload: LoginPayload) {
    const email = this.requireEmail(payload.email);
    const password = this.requirePassword(payload.password);

    const supabase = this.supabaseService.getClient();
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) throw new UnauthorizedException(error.message);

    return {
      user: data.user,
      session: data.session,
    };
  }

  private requireEmail(value?: string): string {
    const email = value?.trim().toLowerCase();
    if (!email || !email.includes('@')) {
      throw new BadRequestException('Valid email is required.');
    }
    return email;
  }

  private requirePassword(value?: string): string {
    if (!value || value.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters.');
    }
    return value;
  }
}
