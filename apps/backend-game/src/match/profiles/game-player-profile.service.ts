import { Injectable } from '@nestjs/common';
import type { BattleLoadout, BattleTarget } from '../../contracts/battle-state';
import { SupabaseService } from '../../supabase/supabase.service';

const DEFAULT_CHARACTER_ID = 'character-basic-squire';
const DEFAULT_TOWER_ID = 'tower-garda-biru';

export type GamePlayerProfile = {
  userId: string;
  displayName: string;
  target: BattleTarget;
  loadout: BattleLoadout;
};

type ProfileRow = {
  id: string;
  username: string | null;
  full_name: string | null;
  target: string | null;
  equipped_avatar_id: string | null;
  equipped_tower_id: string | null;
};

@Injectable()
export class GamePlayerProfileService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getProfile(userId: string): Promise<GamePlayerProfile> {
    const adminClient = this.supabaseService.getAdminClient();
    const { data, error } = await adminClient
      .from('profiles')
      .select(
        'id, username, full_name, target, equipped_avatar_id, equipped_tower_id',
      )
      .eq('id', userId)
      .single();

    if (error || !data) {
      throw new Error(
        `Failed to load game profile: ${error?.message ?? 'profile not found'}`,
      );
    }

    return this.mapProfile(data as ProfileRow);
  }

  botProfile(target: BattleTarget): GamePlayerProfile {
    return {
      userId: 'bot',
      displayName: 'BOT YUDHA',
      target,
      loadout: {
        characterId: 'character-rare-brock',
        towerId: 'tower-benteng-bara',
      },
    };
  }

  private mapProfile(row: ProfileRow): GamePlayerProfile {
    const target = row.target?.toLowerCase();
    if (target !== 'cpns' && target !== 'bumn') {
      throw new Error('Game profile target must be cpns or bumn.');
    }

    const fullName = row.full_name?.trim();
    const preferredName = fullName || row.username?.trim() || 'Player';
    const displayName = preferredName.split(/\s+/u)[0];

    return {
      userId: row.id,
      displayName,
      target,
      loadout: {
        characterId: row.equipped_avatar_id ?? DEFAULT_CHARACTER_ID,
        towerId: row.equipped_tower_id ?? DEFAULT_TOWER_ID,
      },
    };
  }
}
