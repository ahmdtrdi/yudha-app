import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { CompanyContextSnapshot } from '../interview.types';
import { formatCompanyBriefing } from '../services/company-context-formatter';

interface LocalCompanyContextRow {
  category: string;
  content: string;
  priority: number;
}

interface LocalCompanyProfile {
  id: string;
  name: string;
  summary: string;
  contentVersion: string;
  defaultTargetRole: string;
}

interface LocalCompanySource {
  title: string;
  url: string;
}

interface LocalCompanyFixture {
  profile: LocalCompanyProfile;
  contexts: LocalCompanyContextRow[];
  sources: LocalCompanySource[];
}

export interface LocalCompanyOption {
  id: string;
  name: string;
}

export interface LoadedLocalCompanyContext {
  snapshot: CompanyContextSnapshot;
  defaultTargetRole: string;
  sources: LocalCompanySource[];
}

const fixtureDirectory = join(__dirname, 'fixtures', 'companies');
const localCompanyOptions: LocalCompanyOption[] = [
  { id: 'pertamina', name: 'PT Pertamina (Persero)' },
  { id: 'bank-mandiri', name: 'PT Bank Mandiri (Persero) Tbk' },
  {
    id: 'kementerian-keuangan',
    name: 'Kementerian Keuangan Republik Indonesia',
  },
];

export function listLocalCompanies(): LocalCompanyOption[] {
  return localCompanyOptions;
}

export async function loadLocalCompanyContext(
  companyId: string,
): Promise<LoadedLocalCompanyContext> {
  assertSupportedCompany(companyId);
  const fixturePath = join(fixtureDirectory, `${companyId}.json`);
  const fixture = parseFixture(
    JSON.parse(await readFile(fixturePath, 'utf8')) as unknown,
    companyId,
  );

  return {
    snapshot: {
      companyId: fixture.profile.id,
      companyName: fixture.profile.name,
      contentVersion: fixture.profile.contentVersion,
      briefing: formatCompanyBriefing(
        fixture.profile.summary,
        fixture.contexts.sort((left, right) => left.priority - right.priority),
        6000,
      ),
    },
    defaultTargetRole: fixture.profile.defaultTargetRole,
    sources: fixture.sources,
  };
}

function assertSupportedCompany(companyId: string): void {
  if (!localCompanyOptions.some((company) => company.id === companyId)) {
    throw new Error(
      `Unknown --company value. Use one of: ${localCompanyOptions
        .map((company) => company.id)
        .join(', ')}.`,
    );
  }
}

function parseFixture(
  value: unknown,
  expectedCompanyId: string,
): LocalCompanyFixture {
  const fixture = value as LocalCompanyFixture;
  if (
    !fixture?.profile ||
    fixture.profile.id !== expectedCompanyId ||
    !fixture.profile.name ||
    !fixture.profile.summary ||
    !fixture.profile.contentVersion ||
    !fixture.profile.defaultTargetRole ||
    !Array.isArray(fixture.contexts) ||
    fixture.contexts.some(
      (context) =>
        !context.category ||
        !context.content ||
        !Number.isInteger(context.priority),
    ) ||
    !Array.isArray(fixture.sources) ||
    fixture.sources.some((source) => !source.title || !source.url)
  ) {
    throw new Error(`Invalid local company fixture: ${expectedCompanyId}.`);
  }

  return fixture;
}
