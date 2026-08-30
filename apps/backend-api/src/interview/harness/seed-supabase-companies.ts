import { createClient } from '@supabase/supabase-js';
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

function getEnv(key: string): string {
  return process.env[key] || '';
}

async function seed() {
  const supabaseUrl = getEnv('SUPABASE_URL');
  const supabaseKey =
    getEnv('SUPABASE_SERVICE_ROLE_KEY') || getEnv('SUPABASE_KEY');

  if (!supabaseUrl || !supabaseKey) {
    console.error(
      ' Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment.',
    );
    console.log(
      ' Tip: You can execute infra/supabase/seed_interview_companies.sql directly in your Supabase SQL Editor.',
    );
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);
  console.log(`Connecting to Supabase project: ${supabaseUrl}`);

  const fixturesDir = path.join(__dirname, 'fixtures', 'companies');
  const files = fs.readdirSync(fixturesDir).filter((f) => f.endsWith('.json'));

  console.log(`Found ${files.length} company profile fixtures to seed.`);

  for (const file of files) {
    const companyId = path.basename(file, '.json');
    const raw = fs.readFileSync(path.join(fixturesDir, file), 'utf-8');
    const json = JSON.parse(raw);

    const companies = Array.isArray(json.companies) ? json.companies : [];
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
      companyId;
    const defaultRole =
      json.profile?.defaultTargetRole || defaultRoles[companyId] || null;

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

    // 1. Upsert Profile
    const { error: profileError } = await supabase
      .from('interview_company_profiles')
      .upsert({
        id: companyId,
        name,
        summary,
        content_version: 'v1',
        ...(defaultRole == null ? {} : { default_role: defaultRole }),
        updated_at: new Date().toISOString(),
      });

    if (profileError) {
      console.error(
        ` Error upserting profile for ${companyId}:`,
        profileError.message,
      );
      continue;
    }

    // 2. Clear old contexts
    await supabase
      .from('interview_company_contexts')
      .delete()
      .eq('company_id', companyId);

    // 3. Build & Insert Contexts
    const contexts: Array<{
      company_id: string;
      category: string;
      content: string;
      priority: number;
    }> = [];
    let priority = 10;

    if (Array.isArray(json.contexts)) {
      for (const ctx of json.contexts) {
        contexts.push({
          company_id: companyId,
          category: ctx.category,
          content: ctx.content,
          priority: ctx.priority || priority,
        });
        priority += 10;
      }
    } else {
      if (
        json.history?.brief ||
        json.history?.overview ||
        json.overview?.description
      ) {
        const text = [
          json.history?.brief ||
            json.history?.overview ||
            json.overview?.description,
          json.history?.milestones
            ? `Milestones:\n- ${Array.isArray(json.history.milestones) ? json.history.milestones.join('\n- ') : json.history.milestones}`
            : '',
        ]
          .filter(Boolean)
          .join('\n\n');

        contexts.push({
          company_id: companyId,
          category: 'Sejarah & Profil Utama',
          content: text,
          priority: (priority += 10),
        });
      }

      if (json.vision_mission || json.vision || json.mission) {
        const vision = json.vision_mission?.vision || json.vision;
        const mission = json.vision_mission?.mission || json.mission;
        const text = [
          vision ? `Visi:\n${vision}` : '',
          mission
            ? `Misi:\n- ${Array.isArray(mission) ? mission.join('\n- ') : mission}`
            : '',
        ]
          .filter(Boolean)
          .join('\n\n');

        if (text) {
          contexts.push({
            company_id: companyId,
            category: 'Visi & Misi',
            content: text,
            priority: (priority += 10),
          });
        }
      }

      if (
        json.core_values ||
        json.work_culture ||
        json.culture_work ||
        json.corporate_culture
      ) {
        const text = [
          json.core_values?.description ||
            json.work_culture?.description ||
            json.culture_work?.description ||
            'AKHLAK BUMN',
        ]
          .filter(Boolean)
          .join('\n\n');

        contexts.push({
          company_id: companyId,
          category: 'Budaya Kerja & Core Values',
          content: text,
          priority: (priority += 10),
        });
      }
    }

    if (contexts.length > 0) {
      const { error: contextError } = await supabase
        .from('interview_company_contexts')
        .insert(contexts);

      if (contextError) {
        console.error(
          `Error inserting contexts for ${companyId}:`,
          contextError.message,
        );
      } else {
        console.log(
          `Successfully seeded company: ${name} (${companyId}) with ${contexts.length} context blocks.`,
        );
      }
    }
  }

  console.log('🎉 Company seeding complete!');
}

seed().catch((err) => {
  console.error('Fatal seed error:', err);
  process.exit(1);
});
