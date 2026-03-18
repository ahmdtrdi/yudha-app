import { ConfigService } from '@nestjs/config';
import { SupabaseClient } from '@supabase/supabase-js';
export declare class SupabaseService {
    private configService;
    private readonly logger;
    private supabase;
    constructor(configService: ConfigService);
    getClient(): SupabaseClient;
}
