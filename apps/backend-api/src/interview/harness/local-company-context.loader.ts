import { readFile, readdir } from 'node:fs/promises';
import { basename, join } from 'node:path';
import { CompanyContextSnapshot } from '../interview.types';
import { formatCompanyBriefing } from '../services/company-context-formatter';

interface LocalCompanyContextRow {
  category: string;
  content: string;
  priority: number;
}

interface LocalCompanySource {
  title: string;
  url: string;
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

export async function listLocalCompanies(): Promise<LocalCompanyOption[]> {
  try {
    const files = await readdir(fixtureDirectory);
    return files
      .filter((f) => f.endsWith('.json'))
      .map((f) => ({
        id: basename(f, '.json'),
        name: basename(f, '.json').replace(/-/g, ' ').toUpperCase(),
      }));
  } catch {
    return [
      { id: 'pertamina', name: 'PT Pertamina (Persero)' },
      { id: 'bank-mandiri', name: 'PT Bank Mandiri (Persero) Tbk' },
      { id: 'kementerian-keuangan', name: 'Kementerian Keuangan RI' },
    ];
  }
}

export async function loadLocalCompanyContext(
  companyId: string,
): Promise<LoadedLocalCompanyContext> {
  const fixturePath = join(fixtureDirectory, `${companyId}.json`);
  let rawText = '';
  try {
    rawText = await readFile(fixturePath, 'utf8');
  } catch {
    throw new Error(`Company fixture file not found: ${companyId}.json`);
  }

  const json = JSON.parse(rawText) as Record<string, any>;
  return parseFlexibleFixture(json, companyId);
}

function parseFlexibleFixture(
  json: Record<string, any>,
  companyId: string,
): LoadedLocalCompanyContext {
  // Extract Name
  const name =
    json.profile?.name ||
    json.company_identity?.full_name ||
    json.institution_identity?.full_name ||
    json.company?.name ||
    json.company_name ||
    companyId;

  // Extract Summary
  const historyBrief =
    json.profile?.summary ||
    json.history?.brief ||
    json.history?.overview ||
    json.overview?.description ||
    '';
  const visionStr = json.vision_mission?.vision || json.vision || '';
  const summary = [
    `${name}.`,
    historyBrief,
    visionStr ? `Visi: ${visionStr}` : '',
  ]
    .filter(Boolean)
    .join(' ');

  // Default Target Role
  const defaultTargetRole =
    json.profile?.defaultTargetRole ||
    json.defaultTargetRole ||
    'Management Trainee / Staf Professional';

  // Extract Contexts
  const contexts: LocalCompanyContextRow[] = [];
  let priority = 10;

  if (Array.isArray(json.contexts)) {
    for (const ctx of json.contexts) {
      contexts.push({
        category: ctx.category || 'Umum',
        content: ctx.content || '',
        priority: ctx.priority || priority,
      });
      priority += 10;
    }
  } else {
    if (json.history || json.overview) {
      const text = [
        json.history?.brief || json.history?.overview || json.overview?.description,
        json.history?.milestones
          ? `Milestones:\n- ${Array.isArray(json.history.milestones) ? json.history.milestones.join('\n- ') : json.history.milestones}`
          : '',
      ]
        .filter(Boolean)
        .join('\n\n');

      if (text) {
        contexts.push({
          category: 'Sejarah & Profil Utama',
          content: text,
          priority: (priority += 10),
        });
      }
    }

    if (json.vision_mission || json.vision || json.mission) {
      const vision = json.vision_mission?.vision || json.vision;
      const mission = json.vision_mission?.mission || json.mission;
      const text = [
        vision ? `Visi:\n${vision}` : '',
        mission ? `Misi:\n- ${Array.isArray(mission) ? mission.join('\n- ') : mission}` : '',
      ]
        .filter(Boolean)
        .join('\n\n');

      if (text) {
        contexts.push({
          category: 'Visi & Misi',
          content: text,
          priority: (priority += 10),
        });
      }
    }

    if (json.core_values || json.work_culture || json.culture_work || json.corporate_culture) {
      const text = [
        json.work_culture?.description ||
          json.culture_work?.description ||
          json.corporate_culture?.description ||
          'Budaya AKHLAK BUMN & Integritas',
      ]
        .filter(Boolean)
        .join('\n\n');

      contexts.push({
        category: 'Budaya Kerja & Core Values',
        content: text,
        priority: (priority += 10),
      });
    }
  }

  const sources: LocalCompanySource[] = Array.isArray(json.sources)
    ? json.sources
    : [{ title: `${name} Official Data`, url: 'https://bumn.go.id' }];

  return {
    snapshot: {
      companyId: json.profile?.id || companyId,
      companyName: name,
      contentVersion: json.profile?.contentVersion || 'v1',
      briefing: formatCompanyBriefing(summary, contexts, 6000),
    },
    defaultTargetRole,
    sources,
  };
}
