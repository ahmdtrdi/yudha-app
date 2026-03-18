import { ProfileService } from './profile.service';
export declare class ProfileController {
    private readonly profileService;
    constructor(profileService: ProfileService);
    getMyProfile(user: any): Promise<{
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
