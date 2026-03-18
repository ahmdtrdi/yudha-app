import { CanActivate, ExecutionContext } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
export declare class SupabaseAuthGuard implements CanActivate {
    private readonly supabaseService;
    constructor(supabaseService: SupabaseService);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
