import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import type { SupabaseService } from '../supabase/supabase.service';
import { StoreService } from './store.service';

describe('StoreService', () => {
  const rpc = jest.fn();
  const get = jest.fn();
  let service: StoreService;

  beforeEach(() => {
    rpc.mockReset();
    get.mockReset();
    service = new StoreService(
      {
        getClient: () => ({ rpc }),
      } as unknown as SupabaseService,
      { get } as unknown as ConfigService,
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

  it('keeps beta credits disabled unless explicitly enabled', async () => {
    get.mockReturnValue('false');

    await expect(
      service.grantBetaCredit('user-1', {
        idempotencyKey: 'request-1',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(rpc).not.toHaveBeenCalled();
  });
});

