import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { ProService } from './pro.service';

describe('ProService', () => {
  let service: ProService;
  let rpc: jest.Mock;
  let order: jest.Mock;
  let typeEq: jest.Mock;
  let exclusiveEq: jest.Mock;
  let activeEq: jest.Mock;
  let select: jest.Mock;
  let from: jest.Mock;
  let configGet: jest.Mock;

  beforeEach(() => {
    rpc = jest.fn();
    order = jest.fn().mockResolvedValue({
      data: [{ id: 'character-pro-garuda', name: 'Garuda Knight', rarity: 'mythic' }],
      error: null,
    });
    typeEq = jest.fn().mockReturnValue({ order });
    exclusiveEq = jest.fn().mockReturnValue({ eq: typeEq });
    activeEq = jest.fn().mockReturnValue({ eq: exclusiveEq });
    select = jest.fn().mockReturnValue({ eq: activeEq });
    from = jest.fn().mockReturnValue({ select });
    configGet = jest.fn().mockReturnValue('false');

    const supabase = {
      getClient: () => ({
        rpc,
        from,
      }),
    };
    const config = {
      get: configGet,
    };

    service = new ProService(supabase as any, config as any);
  });

  describe('getStatus', () => {
    it('returns Pro plan, entitlement, and exclusive skins with checkout disabled', async () => {
      rpc.mockResolvedValue({
        data: {
          policyVersion: 'economy-policy.v1',
          pro: {
            active: true,
            expiresAt: '2026-10-02T00:00:00.000Z',
            unlimitedEnergy: true,
            selectedSkinId: 'character-pro-garuda',
          },
        },
        error: null,
      });

      const result = await service.getStatus('user-pro');

      expect(rpc).toHaveBeenCalledWith('get_economy_state', {
        p_user_id: 'user-pro',
      });
      expect(result.data.plan.checkoutEnabled).toBe(false);
      expect(result.data.plan.disabledCode).toBe('FEATURE_DISABLED');
      expect(result.data.entitlement.active).toBe(true);
      expect(result.data.exclusiveSkins).toHaveLength(1);
      expect(result.data.betaActivationEnabled).toBe(false);
    });
  });

  describe('activateBeta', () => {
    it('throws ForbiddenException when beta activation is disabled', async () => {
      configGet.mockReturnValue('false');

      await expect(
        service.activateBeta('user-1', {
          planId: 'pro-monthly',
          idempotencyKey: 'beta-act-1',
        }),
      ).rejects.toThrow(ForbiddenException);

      expect(rpc).not.toHaveBeenCalled();
    });

    it('activates beta entitlement when ENABLE_BETA_PRO_ACTIVATION is true', async () => {
      configGet.mockReturnValue('true');
      rpc.mockResolvedValue({
        data: {
          activated: true,
          planId: 'pro-monthly',
          expiresAt: '2026-10-02T00:00:00.000Z',
          coinsGranted: 500,
          skinGranted: 'character-pro-garuda',
        },
        error: null,
      });

      const result = await service.activateBeta('user-1', {
        planId: 'pro-monthly',
        skinId: 'character-pro-garuda',
        idempotencyKey: 'beta-act-2',
      });

      expect(rpc).toHaveBeenCalledWith('activate_pro_beta', {
        p_user_id: 'user-1',
        p_plan_id: 'pro-monthly',
        p_skin_id: 'character-pro-garuda',
        p_idempotency_key: 'beta-act-2',
      });
      expect(result.data.activated).toBe(true);
    });

    it('maps PRO_ALREADY_ACTIVE to ConflictException', async () => {
      configGet.mockReturnValue('true');
      rpc.mockResolvedValue({
        data: null,
        error: { message: 'PRO_ALREADY_ACTIVE' },
      });

      await expect(
        service.activateBeta('user-1', {
          planId: 'pro-monthly',
          idempotencyKey: 'beta-act-3',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });
});
