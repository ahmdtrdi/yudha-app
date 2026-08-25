import { BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { NotificationsService } from './notifications.service';

function serviceWithPreferenceRow(row: Record<string, unknown> | null = null) {
  const maybeSingle = jest.fn().mockResolvedValue({ data: row, error: null });
  const eq = jest.fn().mockReturnValue({ maybeSingle });
  const select = jest.fn().mockReturnValue({ eq });
  const supabase = { from: jest.fn().mockReturnValue({ select }) };
  return {
    service: new NotificationsService({
      getClient: () => supabase,
    } as unknown as SupabaseService),
    supabase,
  };
}

describe('NotificationsService', () => {
  it('returns disabled default preferences before the user opts in', async () => {
    const { service } = serviceWithPreferenceRow();

    await expect(service.getPreferences('user-1')).resolves.toEqual({
      enabled: false,
      morningEnabled: true,
      morningTime: '09:00',
      rescueEnabled: true,
      rescueTime: '19:30',
    });
  });

  it('rejects invalid editable reminder times', async () => {
    const { service } = serviceWithPreferenceRow();

    await expect(
      service.updatePreferences('user-1', { morningTime: '25:10' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it.each(['Not/AZone', '', 'x'.repeat(101)])(
    'rejects invalid installation time zone %s',
    async (timeZone) => {
      const { service } = serviceWithPreferenceRow();
      await expect(
        service.registerInstallation(
          'user-1',
          '11111111-1111-4111-8111-111111111111',
          { token: 'a'.repeat(30), platform: 'android', timeZone },
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    },
  );
});
