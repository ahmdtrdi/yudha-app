import type { SupabaseService } from '../../supabase/supabase.service';
import { GamePlayerProfileService } from './game-player-profile.service';

describe('GamePlayerProfileService', () => {
  const single = jest.fn();
  const eq = jest.fn(() => ({ single }));
  const select = jest.fn(() => ({ eq }));
  const from = jest.fn(() => ({ select }));
  const service = new GamePlayerProfileService({
    getAdminClient: () => ({ from }),
  } as unknown as SupabaseService);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('uses the first word of full_name instead of username in battle', async () => {
    single.mockResolvedValue({
      data: {
        id: 'user-1',
        username: 'raka_123',
        full_name: 'Raka Saputra',
        target: 'cpns',
        equipped_avatar_id: 'character-basic-pip',
        equipped_tower_id: 'tower-benteng-bara',
      },
      error: null,
    });

    await expect(service.getProfile('user-1')).resolves.toEqual({
      userId: 'user-1',
      displayName: 'Raka',
      target: 'cpns',
      loadout: {
        characterId: 'character-basic-pip',
        towerId: 'tower-benteng-bara',
      },
    });
  });

  it('falls back to username when full_name is empty', async () => {
    single.mockResolvedValue({
      data: {
        id: 'user-2',
        username: 'bima',
        full_name: null,
        target: 'bumn',
        equipped_avatar_id: null,
        equipped_tower_id: null,
      },
      error: null,
    });

    await expect(service.getProfile('user-2')).resolves.toMatchObject({
      displayName: 'bima',
      loadout: {
        characterId: 'character-basic-squire',
        towerId: 'tower-garda-biru',
      },
    });
  });
});
