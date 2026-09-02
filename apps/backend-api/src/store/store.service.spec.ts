import {
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import type { SupabaseService } from '../supabase/supabase.service';
import { StoreService } from './store.service';

describe('StoreService', () => {
  const rpc = jest.fn();
  let service: StoreService;

  beforeEach(() => {
    rpc.mockReset();
    service = new StoreService(
      {
        getClient: () => ({ rpc }),
      } as unknown as SupabaseService,
    );
  });

  it('purchases through the atomic RPC', async () => {
    rpc.mockResolvedValue({
      data: {
        purchased: true,
        purchaseId: 'purchase-1',
        itemId: 'character-basic-pip',
        coins: 500,
      },
      error: null,
    });

    await expect(
      service.purchase('user-1', {
        itemId: 'character-basic-pip',
        idempotencyKey: 'request-1',
      }),
    ).resolves.toEqual({
      data: {
        purchased: true,
        purchaseId: 'purchase-1',
        itemId: 'character-basic-pip',
        coins: 500,
      },
    });
    expect(rpc).toHaveBeenCalledWith('purchase_store_item', {
      p_user_id: 'user-1',
      p_item_id: 'character-basic-pip',
      p_idempotency_key: 'request-1',
    });
  });

  it('maps duplicate ownership to conflict', async () => {
    rpc.mockResolvedValue({
      data: null,
      error: { message: 'Store item is already owned.' },
    });

    await expect(
      service.purchase('user-1', {
        itemId: 'character-basic-pip',
        idempotencyKey: 'request-1',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('validates purchase input before calling Supabase', async () => {
    await expect(
      service.purchase('user-1', {
        itemId: '',
        idempotencyKey: 'request-1',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(rpc).not.toHaveBeenCalled();
  });

  it('persists an owned profile loadout through the authoritative RPC', async () => {
    rpc.mockResolvedValue({
      data: {
        characterId: 'character-basic-pip',
        towerId: 'tower-benteng-bara',
        arenaId: 'arena-cpns',
      },
      error: null,
    });

    await expect(
      service.setLoadout('user-1', {
        characterId: 'character-basic-pip',
        towerId: 'tower-benteng-bara',
      }),
    ).resolves.toEqual({
      data: {
        characterId: 'character-basic-pip',
        towerId: 'tower-benteng-bara',
        arenaId: 'arena-cpns',
      },
    });
    expect(rpc).toHaveBeenCalledWith('set_profile_loadout', {
      p_user_id: 'user-1',
      p_avatar_id: 'character-basic-pip',
      p_tower_id: 'tower-benteng-bara',
      p_arena_id: null,
    });
  });

  it('requires at least one loadout field', async () => {
    await expect(service.setLoadout('user-1', {})).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(rpc).not.toHaveBeenCalled();
  });
});
