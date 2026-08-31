import {
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../../supabase/supabase.service';
import { CompanyContextSnapshot } from '../interview.types';
import { formatCompanyBriefing } from './company-context-formatter';

interface CompanyProfileRow {
  id: string;
  name: string;
  summary: string;
  content_version: string;
}

interface CompanyCatalogRow {
  id: string;
  name: string;
  default_role: string | null;
}

interface CompanyContextRow {
  category: string;
  content: string;
}

@Injectable()
export class CompanyContextService {
  private readonly maxItems: number;
  private readonly maxChars: number;

  constructor(
    private readonly supabaseService: SupabaseService,
    configService: ConfigService,
  ) {
    this.maxItems = this.getPositiveInteger(
      configService,
      'INTERVIEW_CONTEXT_MAX_ITEMS',
      5,
    );
    this.maxChars = this.getPositiveInteger(
      configService,
      'INTERVIEW_CONTEXT_MAX_CHARS',
      6000,
    );
  }

  async listCompanies() {
    const supabase = this.supabaseService.getClient();
    const { data: companies, error } = await supabase
      .from('interview_company_profiles')
      .select('id, name, default_role')
      .order('name', { ascending: true })
      .returns<CompanyCatalogRow[]>();

    if (error) {
      throw new InternalServerErrorException(error.message);
    }

    return {
      companies: (companies ?? []).map((company) => ({
        id: company.id,
        name: company.name,
        defaultRole: company.default_role,
      })),
    };
  }

  async resolveSnapshot(companyId: string): Promise<CompanyContextSnapshot> {
    const supabase = this.supabaseService.getClient();
    const { data: profile, error: profileError } = await supabase
      .from('interview_company_profiles')
      .select('id, name, summary, content_version')
      .eq('id', companyId)
      .single<CompanyProfileRow>();

    if (profileError || !profile) {
      if (profileError?.code === 'PGRST116') {
        throw new NotFoundException('Interview company profile not found.');
      }

      throw new InternalServerErrorException(
        profileError?.message ?? 'Failed to load company profile.',
      );
    }

    const { data: contexts, error: contextsError } = await supabase
      .from('interview_company_contexts')
      .select('category, content')
      .eq('company_id', companyId)
      .order('priority', { ascending: true })
      .limit(this.maxItems)
      .returns<CompanyContextRow[]>();

    if (contextsError) {
      throw new InternalServerErrorException(contextsError.message);
    }

    return {
      companyId: profile.id,
      companyName: profile.name,
      contentVersion: profile.content_version,
      briefing: formatCompanyBriefing(
        profile.summary,
        contexts ?? [],
        this.maxChars,
      ),
    };
  }

  private getPositiveInteger(
    configService: ConfigService,
    key: string,
    fallback: number,
  ): number {
    const value = Number(configService.get<string>(key, String(fallback)));
    if (!Number.isInteger(value) || value <= 0) {
      throw new Error(`${key} must be a positive integer.`);
    }

    return value;
  }
}
