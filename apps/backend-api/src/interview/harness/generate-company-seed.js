const fs = require('fs');
const path = require('path');

function escapeSql(text) {
  if (typeof text !== 'string') text = String(text || '');
  return text.replace(/'/g, "''");
}

function stringifyVal(val) {
  if (!val) return '';
  if (typeof val === 'string') return val;
  if (Array.isArray(val)) {
    return val
      .map((item) => {
        if (typeof item === 'string') return item;
        if (typeof item === 'object') return JSON.stringify(item);
        return String(item);
      })
      .join('\n- ');
  }
  if (typeof val === 'object') {
    return Object.entries(val)
      .map(([k, v]) => `${k}: ${typeof v === 'object' ? JSON.stringify(v) : v}`)
      .join('\n');
  }
  return String(val);
}

function parseFixture(companyId, json) {
  const name =
    json.company_identity?.full_name ||
    json.institution_identity?.full_name ||
    json.company?.name ||
    json.company_name ||
    json.profile?.name ||
    companyId;

  const historyBrief =
    json.history?.brief ||
    json.history?.overview ||
    json.overview?.description ||
    json.profile?.summary ||
    '';
  const visionStr = json.vision_mission?.vision || json.vision || '';

  const summary = [
    `${name}.`,
    historyBrief,
    visionStr ? `Visi: ${visionStr}` : '',
  ]
    .filter(Boolean)
    .join(' ');

  const contexts = [];
  let priority = 10;

  // Direct contexts array handling (e.g. kementerian-keuangan)
  if (Array.isArray(json.contexts)) {
    for (const ctx of json.contexts) {
      contexts.push({
        category: ctx.category,
        content: ctx.content,
        priority: ctx.priority || priority,
      });
      priority += 10;
    }
    return { name, summary, contexts };
  }

  // 1. History & Overview
  if (json.history || json.overview || json.company) {
    const historyOverview = json.history?.brief || json.history?.overview || json.overview?.description;
    const milestonesStr = json.history?.milestones
      ? Array.isArray(json.history.milestones)
        ? json.history.milestones
            .map((m) => (typeof m === 'object' ? `${m.year || ''}: ${m.event || JSON.stringify(m)}` : m))
            .join('\n- ')
        : String(json.history.milestones)
      : json.history?.key_milestones
      ? json.history.key_milestones.map((m) => `${m.year}: ${m.event}`).join('\n- ')
      : '';

    const content = [
      historyOverview ? `Overview & Sejarah:\n${historyOverview}` : '',
      milestonesStr ? `Milestones:\n- ${milestonesStr}` : '',
      json.overview?.legal_basis ? `Dasar Hukum: ${json.overview.legal_basis}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    if (content) {
      contexts.push({
        category: 'Sejarah & Profil Utama',
        content,
        priority: (priority += 10),
      });
    }
  }

  // 2. Vision & Mission
  if (json.vision_mission || json.vision || json.mission) {
    const vision = json.vision_mission?.vision || json.vision;
    const mission = json.vision_mission?.mission || json.mission;

    const content = [
      vision ? `Visi:\n${vision}` : '',
      mission ? `Misi:\n- ${Array.isArray(mission) ? mission.join('\n- ') : mission}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    if (content) {
      contexts.push({
        category: 'Visi & Misi',
        content,
        priority: (priority += 10),
      });
    }
  }

  // 3. Core Values & Culture
  if (json.core_values || json.work_culture || json.culture_work || json.corporate_culture) {
    const akhlakVal =
      json.core_values?.akhlak ||
      json.core_values?.core_values ||
      json.corporate_culture?.core_values ||
      json.core_values?.name;
    const akhlakStr = stringifyVal(akhlakVal);

    const cultureDesc =
      json.work_culture?.description ||
      json.culture_work?.description ||
      json.corporate_culture?.description ||
      json.core_values?.description;

    const content = [
      akhlakStr ? `Nilai Utama & Budaya (AKHLAK/Core Values):\n- ${akhlakStr}` : '',
      json.core_values?.behavior_guidelines ? `Panduan Perilaku: ${json.core_values.behavior_guidelines}` : '',
      cultureDesc ? `Budaya Kerja: ${cultureDesc}` : '',
      json.culture_work?.key_elements ? `Elemen Utama Budaya:\n- ${json.culture_work.key_elements.join('\n- ')}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    if (content) {
      contexts.push({
        category: 'Budaya Kerja & Core Values',
        content,
        priority: (priority += 10),
      });
    }
  }

  // 4. Business Lines / Functions / Products
  if (
    json.business_lines ||
    json.products_services ||
    json.centrality_role ||
    json.main_functions ||
    json.subsidiaries
  ) {
    const linesStr = Array.isArray(json.business_lines)
      ? json.business_lines.map((l) => `• ${l.name}: ${l.description}`).join('\n')
      : '';

    const subsidiariesStr = Array.isArray(json.subsidiaries)
      ? json.subsidiaries.map((s) => `• ${s.name} (${s.ownership || ''}): ${s.business || s.description || ''}`).join('\n')
      : '';

    const content = [
      linesStr ? `Lini Bisnis Utama:\n${linesStr}` : '',
      subsidiariesStr ? `Anak Perusahaan & Unit Usaha:\n${subsidiariesStr}` : '',
      json.products_services?.main ? `Produk & Layanan Utama: ${json.products_services.main}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    if (content) {
      contexts.push({
        category: 'Lini Bisnis & Peran Utama',
        content,
        priority: (priority += 10),
      });
    }
  }

  // 5. Governance & Board Structure
  if (json.board_structure || json.organizational_structure || json.governance) {
    const commissionersList =
      json.board_structure?.board_of_commissioners || json.board_structure?.commissioners;
    const directorsList =
      json.board_structure?.board_of_directors || json.board_structure?.directors;

    const commissioners = Array.isArray(commissionersList)
      ? commissionersList.map((c) => `• ${c.position}: ${c.name}`).join('\n')
      : '';
    const directors = Array.isArray(directorsList)
      ? directorsList.map((d) => `• ${d.position}: ${d.name}`).join('\n')
      : '';

    const content = [
      commissioners ? `Dewan Komisaris:\n${commissioners}` : '',
      directors ? `Dewan Direksi:\n${directors}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    if (content) {
      contexts.push({
        category: 'Struktur Kepemimpinan & Governance',
        content,
        priority: (priority += 10),
      });
    }
  }

  // 6. ESG & Programs
  if (json.esg || json.esg_and_sustainability || json.programs || json.awards) {
    const esgCommitment =
      json.esg?.strategy ||
      json.esg_and_sustainability?.commitment ||
      json.esg_and_sustainability?.commitment;
    
    const awardsStr = Array.isArray(json.awards) ? json.awards.join('\n- ') : '';

    const content = [
      esgCommitment ? `Komitmen ESG: ${esgCommitment}` : '',
      awardsStr ? `Penghargaan Utama:\n- ${awardsStr}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    if (content) {
      contexts.push({
        category: 'Inisiatif Strategis, Digital & ESG',
        content,
        priority: (priority += 10),
      });
    }
  }

  return { name, summary, contexts };
}

function run() {
  const fixturesDir = path.join(__dirname, 'fixtures', 'companies');
  const files = fs.readdirSync(fixturesDir).filter((f) => f.endsWith('.json'));

  const sqlLines = [
    '-- ============================================================================',
    '-- SQL SEED SCRIPT: Interview Company Profiles & Contexts',
    '-- Target Tables: public.interview_company_profiles & public.interview_company_contexts',
    '-- Generated at: ' + new Date().toISOString(),
    '-- ============================================================================',
    '',
    'BEGIN;',
    '',
  ];

  for (const file of files) {
    const companyId = path.basename(file, '.json');
    const raw = fs.readFileSync(path.join(fixturesDir, file), 'utf-8');
    const json = JSON.parse(raw);

    const { name, summary, contexts } = parseFixture(companyId, json);

    sqlLines.push(`-- ----------------------------------------------------------------------------`);
    sqlLines.push(`-- Company: ${name} (${companyId})`);
    sqlLines.push(`-- ----------------------------------------------------------------------------`);
    sqlLines.push(
      `INSERT INTO public.interview_company_profiles (id, name, summary, content_version)`
    );
    sqlLines.push(
      `VALUES ('${companyId}', '${escapeSql(name)}', '${escapeSql(summary)}', 'v1')`
    );
    sqlLines.push(
      `ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, updated_at = now();`
    );
    sqlLines.push('');
    sqlLines.push(`DELETE FROM public.interview_company_contexts WHERE company_id = '${companyId}';`);

    for (const ctx of contexts) {
      sqlLines.push(
        `INSERT INTO public.interview_company_contexts (company_id, category, content, priority)`
      );
      sqlLines.push(
        `VALUES ('${companyId}', '${escapeSql(ctx.category)}', '${escapeSql(ctx.content)}', ${ctx.priority});`
      );
    }

    sqlLines.push('');
  }

  sqlLines.push('COMMIT;');
  sqlLines.push('');

  const outputPath = path.join(__dirname, '../../../../../infra/supabase/seed_interview_companies.sql');
  fs.writeFileSync(outputPath, sqlLines.join('\n'), 'utf-8');
  console.log(`Successfully generated SQL seed for ${files.length} companies -> ${outputPath}`);
}

run();
