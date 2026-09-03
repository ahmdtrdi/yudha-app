import {
  BadRequestException,
  ConflictException,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { EconomyService } from './economy.service';

describe('EconomyService', () => {
  let service: EconomyService;
  let rpc: jest.Mock;
  let single: jest.Mock;
  let eq: jest.Mock;
  let select: jest.Mock;
  let from: jest.Mock;
  let adVerifier: { verify: jest.Mock };

  beforeEach(() => {
    rpc = jest.fn();
    single = jest.fn();
    eq = jest.fn().mockReturnValue({ single });
    select = jest.fn().mockReturnValue({ eq });
    from = jest.fn().mockReturnValue({ select });
    adVerifier = {
      verify: jest.fn().mockResolvedValue({
        provider: 'mock-ad-network',
        providerTransactionId: 'tx-12345',
      }),
    };

    const supabase = {
      getClient: () => ({
        rpc,
        from,
      }),
    };

    service = new EconomyService(supabase as any, adVerifier as any);
  });

  describe('getState', () => {
    it('returns economy state from authoritative get_economy_state RPC', async () => {
      rpc.mockResolvedValue({
        data: {
          policyVersion: 'economy-policy.v1',
          energy: { balance: 10, cap: 10, unlimited: false },
          yCoins: 250,
          pro: { active: false, expiresAt: null, unlimitedEnergy: false },
        },
        error: null,
      });

      const result = await service.getState('user-1');

      expect(rpc).toHaveBeenCalledWith('get_economy_state', {
        p_user_id: 'user-1',
      });
      expect(result.data).toMatchObject({
        policyVersion: 'economy-policy.v1',
        energy: { balance: 10, cap: 10 },
        yCoins: 250,
      });
    });

    it('throws ConflictException on economy rule conflicts', async () => {
      rpc.mockResolvedValue({
        data: null,
        error: { message: 'INSUFFICIENT_ENERGY' },
      });

      await expect(service.getState('user-1')).rejects.toThrow(ConflictException);
    });
  });

  describe('getCatalog', () => {
    it('reads active policy version and disables real-money checkout', async () => {
      single.mockResolvedValue({
        data: {
          id: 'economy-policy.v1',
          policy: {
            balancingStatus: 'active',
            energy: { freeStartingBalance: 10, dailyFreeRefillTarget: 10 },
            yCoin: { paidPackages: [{ id: 'ycoin-100', priceIdr: 10000 }] },
          },
        },
        error: null,
      });

      const catalog = await service.getCatalog();

      expect(catalog.data.policyVersion).toBe('economy-policy.v1');
      expect(catalog.data.paidPurchasesEnabled).toBe(false);
      expect(catalog.data.disabledCode).toBe('FEATURE_DISABLED');
      expect(catalog.data.paidYCoinPackages).toHaveLength(1);
    });
  });

  describe('purchaseEnergy', () => {
    it('normalizes a legacy mobile package ID before calling the RPC', async () => {
      rpc.mockResolvedValue({
        data: {
          purchased: true,
          energyAdded: 5,
          energyBalance: 15,
          coinsCharged: 50,
        },
        error: null,
      });

      const result = await service.purchaseEnergy('user-1', {
        packageId: 'energy-pack-5',
        idempotencyKey: 'idemp-energy-1',
      });

      expect(rpc).toHaveBeenCalledWith('purchase_energy_pack', {
        p_user_id: 'user-1',
        p_package_id: 'energy-5',
        p_idempotency_key: 'idemp-energy-1',
      });
      expect(result.data.purchased).toBe(true);
    });

    it('throws ConflictException when energy cap is reached or coins are insufficient', async () => {
      rpc.mockResolvedValue({
        data: null,
        error: { message: 'ENERGY_CAP_REACHED' },
      });

      await expect(
        service.purchaseEnergy('user-1', {
          packageId: 'energy-pack-5',
          idempotencyKey: 'idemp-energy-2',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('maps an unknown energy package to NotFoundException', async () => {
      rpc.mockResolvedValue({
        data: null,
        error: { message: 'NOT_FOUND: energy package' },
      });

      await expect(
        service.purchaseEnergy('user-1', {
          packageId: 'unknown-pack',
          idempotencyKey: 'idemp-energy-3',
        }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('claimAdReward', () => {
    it('verifies proof token and calls claim_verified_ad_reward RPC', async () => {
      rpc.mockResolvedValue({
        data: {
          claimed: true,
          rewardType: 'energy',
          energyAdded: 1,
          energyBalance: 9,
        },
        error: null,
      });

      const result = await service.claimAdReward('user-1', {
        rewardType: 'energy',
        placementId: 'rewarded-post-match',
        proofToken: 'valid-proof-token-xyz',
        idempotencyKey: 'ad-claim-1',
      });

      expect(adVerifier.verify).toHaveBeenCalledWith({
        userId: 'user-1',
        rewardType: 'energy',
        placementId: 'rewarded-post-match',
        proofToken: 'valid-proof-token-xyz',
      });
      expect(rpc).toHaveBeenCalledWith(
        'claim_verified_ad_reward',
        expect.objectContaining({
          p_user_id: 'user-1',
          p_reward_type: 'energy',
          p_provider: 'mock-ad-network',
          p_provider_transaction_id: 'tx-12345',
          p_idempotency_key: 'ad-claim-1',
        }),
      );
      expect(result.data.claimed).toBe(true);
    });

    it('validates rewardType input', async () => {
      await expect(
        service.claimAdReward('user-1', {
          rewardType: 'invalid_type' as any,
          placementId: 'p1',
          proofToken: 'token',
          idempotencyKey: 'k1',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
