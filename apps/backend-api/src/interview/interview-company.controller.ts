import { Controller, Get, UseGuards } from '@nestjs/common';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { CompanyContextService } from './services/company-context.service';

@Controller('interview/companies')
@UseGuards(SupabaseAuthGuard)
export class InterviewCompanyController {
  constructor(private readonly companyContextService: CompanyContextService) {}

  @Get()
  listCompanies() {
    return this.companyContextService.listCompanies();
  }
}
