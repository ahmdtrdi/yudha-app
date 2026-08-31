import * as fs from 'fs';
import * as path from 'path';

const defaultRoles: Record<string, string> = {
  'adhi-karya': 'Management Trainee',
  'bank-indonesia': 'Asisten Manajer',
  'bank-mandiri': 'Officer Development Program',
  'garuda-indonesia': 'Management Trainee',
  'kementerian-keuangan': 'Staf Pengelola Keuangan Negara',
  pertamina: 'Bimbingan Profesi Sarjana',
};

interface CompanyFixture {
  company_identity?: {
    full_name?: string;
    legal_name?: string;
    brand_name?: string;
    nickname?: string;
    status?: string;
    establishment_date?: string;
    head_office?: { address?: string; website?: string };
  };
  company?: { name?: string; nama_lengkap?: string };
  company_name?: string;
  companies?: Array<{ name?: string }>;
  profile?: { name?: string; defaultTargetRole?: string };
  institution_identity?: {
    full_name?: string;
    nickname?: string;
    status?: string;
    establishment_date?: string;
  };
  name?: string;
  summary?: string;
  history?: { brief?: string; milestones?: string[] };
  vision_mission?: { vision?: string; mission?: string[] };
  core_values?: {
    akhlak?: string[];
    additional_culture?: string;
    core_values?: string[];
  };
  business_lines?: Array<{ name: string; description: string }>;
  work_culture?: { description?: string };
  esg_and_sustainability?: { commitment?: string; key_pillars?: string[] };
  board_structure?: {
    board_of_commissioners?: Array<{ position: string; name: string }>;
    board_of_directors?: Array<{ position: string; name: string }>;
  };
  sources?: string;
}

function escapeSql(text: string): string {
  return text.replace(/'/g, "''");
}

function formatCompany(companyId: string, json: CompanyFixture) {
  const companies = json.companies ?? [];
  const matchingNestedCompany =
    companyId === 'perusahaan-listrik-negara'
      ? companies.find((company) => company.name?.includes('PLN'))
      : companies[0];
  const name =
    json.company_identity?.full_name ||
    json.company_identity?.legal_name ||
    json.company_identity?.brand_name ||
    json.institution_identity?.full_name ||
    json.company?.name ||
    json.company?.nama_lengkap ||
    json.company_name ||
    json.profile?.name ||
    matchingNestedCompany?.name ||
    json.name ||
    companyId;
  const defaultRole =
    json.profile?.defaultTargetRole || defaultRoles[companyId] || null;

  const historyBrief = json.history?.brief || '';
  const visionStr = json.vision_mission?.vision || '';
  const summary = [
    `${name} (${json.company_identity?.status || json.institution_identity?.status || 'BUMN/Instansi'}).`,
    historyBrief,
    visionStr ? `Visi: ${visionStr}` : '',
  ]
    .filter(Boolean)
    .join(' ');

  const contexts: Array<{
    category: string;
    content: string;
    priority: number;
  }> = [];
  let priority = 10;

  // 1. History & Identity
  if (json.history?.brief || json.history?.milestones) {
    const content = [
      json.history?.brief ? `Sejarah: ${json.history.brief}` : '',
      json.history?.milestones
        ? `Milestones:\n- ${json.history.milestones.join('\n- ')}`
        : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    contexts.push({
      category: 'Sejarah & Profil Utama',
      content,
      priority: (priority += 10),
    });
  }

  // 2. Vision Mission
  if (json.vision_mission) {
    const content = [
      json.vision_mission.vision ? `Visi:\n${json.vision_mission.vision}` : '',
      json.vision_mission.mission
        ? `Misi:\n- ${json.vision_mission.mission.join('\n- ')}`
        : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    contexts.push({
      category: 'Visi & Misi',
      content,
      priority: (priority += 10),
    });
  }

  // 3. Core Values & Work Culture
  if (json.core_values || json.work_culture) {
    const akhlakList =
      json.core_values?.akhlak || json.core_values?.core_values;
    const content = [
      akhlakList
        ? `Core Values (AKHLAK/Nilai Utama):\n- ${akhlakList.join('\n- ')}`
        : '',
      json.core_values?.additional_culture
        ? `Budaya Tambahan: ${json.core_values.additional_culture}`
        : '',
      json.work_culture?.description
        ? `Budaya Kerja: ${json.work_culture.description}`
        : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    contexts.push({
      category: 'Budaya Kerja & Core Values',
      content,
      priority: (priority += 10),
    });
  }

  // 4. Business Lines / Core Tasks
  if (json.business_lines && json.business_lines.length > 0) {
    const linesStr = json.business_lines
      .map((line) => `• ${line.name}: ${line.description}`)
      .join('\n');
    contexts.push({
      category: 'Lini Bisnis & Operasional',
      content: `Lini Bisnis Utama:\n${linesStr}`,
      priority: (priority += 10),
    });
  }

  // 5. Board Structure / Leadership
  if (json.board_structure) {
    const commissioners = json.board_structure.board_of_commissioners
      ?.map((c) => `• ${c.position}: ${c.name}`)
      .join('\n');
    const directors = json.board_structure.board_of_directors
      ?.map((d) => `• ${d.position}: ${d.name}`)
      .join('\n');

    const content = [
      commissioners ? `Dewan Komisaris / Pengawas:\n${commissioners}` : '',
      directors ? `Dewan Direksi:\n${directors}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    if (content) {
      contexts.push({
        category: 'Struktur Kepemimpinan & Direksi',
        content,
        priority: (priority += 10),
      });
    }
  }

  // 6. ESG & Initiatives
  if (json.esg_and_sustainability) {
    const content = [
      json.esg_and_sustainability.commitment
        ? `Komitmen ESG: ${json.esg_and_sustainability.commitment}`
        : '',
      json.esg_and_sustainability.key_pillars
        ? `Pilar ESG:\n- ${json.esg_and_sustainability.key_pillars.join('\n- ')}`
        : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    contexts.push({
      category: 'ESG & Keberlanjutan',
      content,
      priority: (priority += 10),
    });
  }

  return { name, summary, defaultRole, contexts };
}

function main() {
  const dir = path.join(__dirname, 'fixtures', 'companies');
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.json'));

  const sqlLines: string[] = [
    '-- SQL Seed Script for Interview Company Profiles & Contexts',
    '-- Target Tables: public.interview_company_profiles & public.interview_company_contexts',
    '-- Generated at: ' + new Date().toISOString(),
    '',
    'BEGIN;',
    '',
  ];

  for (const file of files) {
    const companyId = path.basename(file, '.json');
    const raw = fs.readFileSync(path.join(dir, file), 'utf-8');
    const json = JSON.parse(raw) as CompanyFixture;

    const { name, summary, defaultRole, contexts } = formatCompany(
      companyId,
      json,
    );
    const defaultRoleSql =
      defaultRole == null ? 'NULL' : `'${escapeSql(defaultRole)}'`;

    sqlLines.push(`-- Company Profile: ${name} (${companyId})`);
    sqlLines.push(
      `INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)`,
    );
    sqlLines.push(
      `VALUES ('${companyId}', '${escapeSql(name)}', '${escapeSql(summary)}', 'v1', ${defaultRoleSql})`,
    );
    sqlLines.push(
      `ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();`,
    );
    sqlLines.push('');

    // Clean existing contexts for re-seed
    sqlLines.push(
      `DELETE FROM public.interview_company_contexts WHERE company_id = '${companyId}';`,
    );

    for (const ctx of contexts) {
      sqlLines.push(
        `INSERT INTO public.interview_company_contexts (company_id, category, content, priority)`,
      );
      sqlLines.push(
        `VALUES ('${companyId}', '${escapeSql(ctx.category)}', '${escapeSql(ctx.content)}', ${ctx.priority});`,
      );
    }

    sqlLines.push('');
  }

  sqlLines.push('COMMIT;');

  const outputPath = path.join(
    __dirname,
    '../../../../../infra/supabase/seed_interview_companies.sql',
  );
  fs.writeFileSync(outputPath, sqlLines.join('\n'), 'utf-8');
  console.log(`Generated seed script at ${outputPath}`);
}

main();
