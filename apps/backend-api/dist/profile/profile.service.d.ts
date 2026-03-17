import { SupabaseService } from '../supabase/supabase.service';
export declare class ProfileService {
    private readonly supabase;
    constructor(supabase: SupabaseService);
    getProfile(userId: string): Promise<{
        id: any;
        username: any;
        rank_points: any;
        total_matches: any;
        wins: any;
        losses: any;
        winrate: any;
        coins: any;
        equipped_avatar_id: any;
        equipped_arena_id: any;
    }>;
}
