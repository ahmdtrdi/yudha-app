import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseService {
  private readonly logger = new Logger(SupabaseService.name);
  private supabase: SupabaseClient;
  private supabaseAdmin: SupabaseClient | null = null;

  constructor(private configService: ConfigService) {
    const supabaseUrl = this.configService.get<string>('SUPABASE_URL');
    const supabaseKey = this.configService.get<string>('SUPABASE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      this.logger.error('Supabase URL or Key is missing from .env file!');
      throw new Error('Missing Supabase credentials');
    }

    this.supabase = createClient(supabaseUrl, supabaseKey);
    this.logger.log('Supabase client successfully initialized 🚀');

    // Initialize admin client if a server-only key is available.
    const secretKey =
      this.configService.get<string>('SUPABASE_SECRET_KEY') ??
      this.configService.get<string>('SUPABASE_SERVICE_ROLE_KEY');
    if (secretKey) {
      this.supabaseAdmin = createClient(supabaseUrl, secretKey, {
        auth: { autoRefreshToken: false, persistSession: false },
      });
        this.logger.log('Supabase admin client initialized (secret key) 🔑');
    }
  }

  /** Public/anon client — used for auth verification */
  getClient(): SupabaseClient {
    return this.supabase;
  }

  /** Service-role client — bypasses RLS for server-side writes */
  getAdminClient(): SupabaseClient {
    if (!this.supabaseAdmin) {
      throw new Error(
        'SUPABASE_SECRET_KEY is not configured. Cannot use admin client.',
      );
    }
    return this.supabaseAdmin;
  }
}
