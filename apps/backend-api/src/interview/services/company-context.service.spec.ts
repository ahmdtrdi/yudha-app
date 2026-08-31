import { InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { SupabaseService } from '../../supabase/supabase.service';
import { CompanyContextService } from './company-context.service';

describe('CompanyContextService company catalog', () => {
  const from = jest.fn();
  const select = jest.fn();
  const order = jest.fn();
  const returns = jest.fn();
  let service: CompanyContextService;

  beforeEach(() => {
    from.mockReset();
    select.mockReset();
    order.mockReset();
    returns.mockReset();
    from.mockReturnValue({ select });
    select.mockReturnValue({ order });
    order.mockReturnValue({ returns });

    service = new CompanyContextService(
      {
        getClient: () => ({ from }),
      } as unknown as SupabaseService,
      {
        get: (_key: string, fallback: string) => fallback,
      } as ConfigService,
    );
  });

  it('lists company profiles alphabetically with nullable default roles', async () => {
    returns.mockResolvedValue({
      data: [
        {
          id: 'bank-indonesia',
          name: 'Bank Indonesia',
          default_role: 'Asisten Manajer',
        },
        {
          id: 'injourney',
          name: 'PT Aviasi Pariwisata Indonesia (Persero)',
          default_role: null,
        },
      ],
      error: null,
    });

    await expect(service.listCompanies()).resolves.toEqual({
      companies: [
        {
          id: 'bank-indonesia',
          name: 'Bank Indonesia',
          defaultRole: 'Asisten Manajer',
        },
        {
          id: 'injourney',
          name: 'PT Aviasi Pariwisata Indonesia (Persero)',
          defaultRole: null,
        },
      ],
    });
    expect(from).toHaveBeenCalledWith('interview_company_profiles');
    expect(select).toHaveBeenCalledWith('id, name, default_role');
    expect(order).toHaveBeenCalledWith('name', { ascending: true });
  });

  it('returns an empty catalog when Supabase has no profiles', async () => {
    returns.mockResolvedValue({ data: null, error: null });

    await expect(service.listCompanies()).resolves.toEqual({ companies: [] });
  });

  it('surfaces Supabase catalog failures', async () => {
    returns.mockResolvedValue({
      data: null,
      error: { message: 'catalog unavailable' },
    });

    await expect(service.listCompanies()).rejects.toBeInstanceOf(
      InternalServerErrorException,
    );
  });
});
