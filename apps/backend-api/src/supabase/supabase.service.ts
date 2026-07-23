import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { Database } from './database.types';

@Injectable()
export class SupabaseService {
  private readonly logger = new Logger(SupabaseService.name);
  private readonly supabase: SupabaseClient<Database>;

  constructor(private configService: ConfigService) {
    const supabaseUrl = this.configService.get<string>('SUPABASE_URL');
    const supabaseKey = this.configService.get<string>(
      'SUPABASE_SERVICE_ROLE_KEY',
    );

    if (!supabaseUrl || !supabaseKey) {
      this.logger.error(
        'SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing.',
      );
      throw new Error('Missing Supabase backend credentials');
    }

    this.supabase = createClient<Database>(supabaseUrl, supabaseKey);
    this.logger.log('Supabase client initialized.');
  }

  getClient(): SupabaseClient<Database> {
    return this.supabase;
  }
}
