import { Test, TestingModule } from '@nestjs/testing';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { InterviewCompanyController } from './interview-company.controller';
import { CompanyContextService } from './services/company-context.service';

describe('InterviewCompanyController', () => {
  const listCompanies = jest.fn();
  let controller: InterviewCompanyController;

  beforeEach(async () => {
    listCompanies.mockReset();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [InterviewCompanyController],
      providers: [
        {
          provide: CompanyContextService,
          useValue: { listCompanies },
        },
      ],
    })
      .overrideGuard(SupabaseAuthGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .compile();

    controller = module.get<InterviewCompanyController>(
      InterviewCompanyController,
    );
  });

  it('returns the authenticated company catalog response', async () => {
    const response = {
      companies: [
        {
          id: 'bank-mandiri',
          name: 'PT Bank Mandiri (Persero) Tbk',
          defaultRole: 'Officer Development Program',
        },
      ],
    };
    listCompanies.mockResolvedValue(response);

    await expect(controller.listCompanies()).resolves.toEqual(response);
    expect(listCompanies).toHaveBeenCalledTimes(1);
  });
});
