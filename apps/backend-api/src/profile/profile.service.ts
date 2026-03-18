import { Injectable, NotFoundException, InternalServerErrorException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class ProfileService {
  constructor(private readonly supabase: SupabaseService) {}

  async getProfile(userId: string) {
    const client = this.supabase.getClient();

    // Query the profiles table using the authenticated user's ID
    const { data, error } = await client
      .from('profiles')
      .select(`
        id, 
        username, 
        rank_points, 
        total_matches, 
        wins, 
        losses, 
        winrate, 
        coins, 
        equipped_avatar_id, 
        equipped_arena_id
      `)
      .eq('id', userId)
      .single(); // .single() ensures we get an object back, not an array

    if (error) {
      // If no rows are found, it might mean the Database Trigger hasn't finished yet,
      // or the user was deleted manually from the database.
      if (error.code === 'PGRST116') { 
        throw new NotFoundException('Profile not found.');
      }
      throw new InternalServerErrorException(error.message);
    }

    return data;
  }
}