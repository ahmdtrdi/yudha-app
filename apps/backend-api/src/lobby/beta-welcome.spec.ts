import { LobbyController } from './lobby.controller';
import { LobbyService } from './lobby.service';

describe('Beta welcome acknowledgment', () => {
  const reward = {
    id: 'reward-1',
    coinAmount: 1000,
    energyAmount: 1000,
    acknowledgedAt: '2026-09-11T00:00:00Z',
  };
  it('uses only the authenticated account id', async () => {
    const rpc = jest.fn().mockResolvedValue({ data: reward, error: null });
    const service = new LobbyService(
      null as any,
      null as any,
      null as any,
      { getClient: () => ({ rpc }) } as any,
      null as any,
    );
    const controller = new LobbyController(service);
    await expect(
      controller.acknowledgeBetaWelcome({ id: 'signed-in-user' }),
    ).resolves.toEqual({ data: reward });
    expect(rpc).toHaveBeenCalledWith('acknowledge_beta_welcome_reward', {
      p_user_id: 'signed-in-user',
    });
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it('returns null for accounts without a grant', async () => {
    const rpc = jest.fn().mockResolvedValue({ data: null, error: null });
    const service = new LobbyService(
      null as any,
      null as any,
      null as any,
      { getClient: () => ({ rpc }) } as any,
      null as any,
    );
    await expect(service.acknowledgeBetaWelcome('old-user')).resolves.toEqual({
      data: null,
    });
  });
  it('does not report acknowledgment success after database failure', async () => {
    const rpc = jest
      .fn()
      .mockResolvedValue({
        data: null,
        error: { message: 'database unavailable' },
      });
    const service = new LobbyService(
      null as any,
      null as any,
      null as any,
      { getClient: () => ({ rpc }) } as any,
      null as any,
    );
    await expect(service.acknowledgeBetaWelcome('user')).rejects.toThrow(
      'database unavailable',
    );
  });
});
