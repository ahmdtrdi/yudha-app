import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseService {
  private readonly logger = new Logger(SupabaseService.name);
  private supabase: SupabaseClient;

  constructor(private configService: ConfigService) {
    // 1. Get the variables from .env
    const supabaseUrl = this.configService.get<string>('SUPABASE_URL');
    const supabaseKey = this.configService.get<string>('SUPABASE_KEY');

    // 2. Safety check
    if (!supabaseUrl || !supabaseKey) {
      this.logger.error('Supabase URL or Key is missing from .env file!');
      throw new Error('Missing Supabase credentials');
    }

    // 3. Initialize the client
    this.supabase = createClient(supabaseUrl, supabaseKey);
    this.logger.log('Supabase client successfully initialized 🚀');
  }

  // 4. Create a method to expose the client to other parts of your app
  getClient(): SupabaseClient {
    return this.supabase;
  }
}