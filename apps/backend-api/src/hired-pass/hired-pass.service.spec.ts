import { ConflictException } from '@nestjs/common';
import type { SupabaseService } from '../supabase/supabase.service';
import { HiredPassService } from './hired-pass.service';

describe('HiredPassService', () => {
  const rpc = jest.fn();
  let service: HiredPassService;

  beforeEach(() => {
    rpc.mockReset();
    service = new HiredPassService({
      getClient: () => ({ rpc }),
    } as unknown as SupabaseService);
  });

  it('claims rewards through the atomic RPC', async () => {
    rpc.mockResolvedValue({
      data: {
        claimed: true,
        rewardId: 'free-100-coins',
        coins: 200,
        itemId: null,
      },
      error: null,
    });

    await expect(
      service.claimReward('user-1', 'free-100-coins'),
    ).resolves.toEqual({
      data: {
        claimed: true,
        rewardId: 'free-100-coins',
        coins: 200,
        itemId: null,
      },
    });
    expect(rpc).toHaveBeenCalledWith('claim_hired_pass_reward', {
      p_user_id: 'user-1',
      p_reward_id: 'free-100-coins',
    });
  });

  it('rejects a repeated reward claim', async () => {
    rpc.mockResolvedValue({
      data: {
        claimed: false,
        reason: 'already_claimed',
        rewardId: 'free-100-coins',
        coins: 200,
      },
      error: null,
    });

    await expect(
      service.claimReward('user-1', 'free-100-coins'),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

