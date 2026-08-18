import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateGate0 } from './validate-gate0.mjs';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..', '..');

export async function syncContent(environment = process.env) {
  await validateGate0(repositoryRoot);
  const baseUrl = required(environment.SUPABASE_URL, 'SUPABASE_URL').replace(/\/$/, '');
  const secret = required(environment.SUPABASE_SECRET_KEY ?? environment.SUPABASE_SERVICE_ROLE_KEY, 'SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY');
  const client = new RestClient(baseUrl, secret);

  const catalog = await load('contracts/content/store-catalog.v1.json');
  const seasonManifest = await load('contracts/content/seasons/2026-08.development.json');
  const banks = await Promise.all([
    load('contracts/content/questions/cpns.v1.json'),
    load('contracts/content/questions/bumn.v1.json'),
  ]);

  await syncCatalog(client, catalog);
  await syncSeason(client, seasonManifest);
  const report = await syncQuestions(client, banks.flatMap((bank) => bank.questions));
  process.stdout.write(`${JSON.stringify({ catalogItems: catalog.items.length, season: seasonManifest.season.id, questions: report })}\n`);
  if (report.duplicate > 0 || report.invalid > 0) {
    throw new Error(`Question import rejected invalid=${report.invalid} duplicate=${report.duplicate}.`);
  }
  return report;
}

async function syncCatalog(client, catalog) {
  const rows = catalog.items.map((item) => ({
    id: item.id,
    type: item.type === 'character' ? 'character_skin' : item.type,
    name: item.name,
    description: item.description,
    rarity: item.rarity,
    coin_price: item.coinPrice,
    is_active: item.active,
    is_pass_exclusive: item.passExclusive,
  }));
  await client.upsert('store_items', rows, 'id');
}

async function syncSeason(client, manifest) {
  await client.updateWhere('hired_pass_seasons', 'is_active=eq.true', {
    is_active: false,
  });
  await client.upsert('hired_pass_seasons', [{
    id: manifest.season.id,
    name: manifest.season.name,
    starts_at: new Date(manifest.season.startsAt).toISOString(),
    ends_at: new Date(manifest.season.endsAt).toISOString(),
    is_active: manifest.releaseActive,
  }], 'id');
  await client.upsert('hired_pass_missions', manifest.missions.map((mission) => ({
    id: mission.id,
    season_id: manifest.season.id,
    title: mission.title,
    description: mission.description,
    event_type: mission.source,
    cadence: mission.cadence,
    target_count: mission.targetCount,
    points_reward: mission.passPoints,
    is_active: true,
  })), 'id');
  await client.upsert('hired_pass_rewards', manifest.rewards.map((reward) => ({
    id: reward.id,
    season_id: manifest.season.id,
    track: reward.track,
    points_required: reward.pointsRequired,
    label: reward.label,
    coins_reward: reward.coins,
    item_id: reward.itemId ?? null,
    is_active: true,
  })), 'id');
}

export async function syncQuestions(client, questions) {
  const existing = await client.selectAll('questions', 'id,source_key,target,prompt,options,content_hash');
  const bySource = new Map(existing.filter((row) => row.source_key).map((row) => [row.source_key, row]));
  const byFingerprint = new Map();
  for (const row of existing) {
    const fingerprint = questionFingerprint(row);
    const matches = byFingerprint.get(fingerprint) ?? [];
    matches.push(row);
    byFingerprint.set(fingerprint, matches);
  }

  const report = { inserted: 0, updated: 0, skipped: 0, invalid: 0, duplicate: 0 };
  const inserts = [];
  const updates = [];
  const inputSourceKeys = new Set();
  for (const question of questions) {
    if (!isValidCanonicalQuestion(question)) {
      report.invalid += 1;
      continue;
    }
    if (inputSourceKeys.has(question.sourceKey)) {
      report.duplicate += 1;
      continue;
    }
    inputSourceKeys.add(question.sourceKey);
    const row = toQuestionRow(question);
    const sourceMatch = bySource.get(row.source_key);
    if (sourceMatch) {
      if (sourceMatch.content_hash === row.content_hash) {
        report.skipped += 1;
      } else {
        updates.push({ id: sourceMatch.id, row });
        report.updated += 1;
      }
      continue;
    }

    const legacyMatches = byFingerprint.get(questionFingerprint(row)) ?? [];
    if (legacyMatches.length > 1) {
      report.duplicate += 1;
      continue;
    }
    if (legacyMatches.length === 1) {
      const match = legacyMatches[0];
      if (
        match.source_key &&
        !String(match.source_key).startsWith('legacy-db:')
      ) {
        report.duplicate += 1;
        continue;
      }
      updates.push({ id: match.id, row });
      report.updated += 1;
      continue;
    }
    inserts.push(row);
  }
  if (report.duplicate > 0 || report.invalid > 0) return report;
  for (const update of updates) {
    await client.update('questions', update.id, update.row);
  }
  if (inserts.length > 0) {
    await client.upsert('questions', inserts, 'source_key');
    report.inserted += inserts.length;
  }
  return report;
}

export function toQuestionRow(question) {
  const content = {
    source_key: question.sourceKey,
    target: question.target,
    category: question.category,
    subcategory: question.subcategory,
    prompt: question.prompt,
    options: question.options,
    correct_option_index: question.correctOptionIndex,
    explanation: question.explanation,
    difficulty: question.difficulty,
    weight: question.weight,
    effect: question.effect,
    damage_value: question.damageValue,
    heal_value: question.healValue,
    time_limit_seconds: question.timeLimitSeconds,
    hint: question.hint,
    is_active: question.active,
  };
  return { ...content, content_hash: createHash('sha256').update(stableJson(content)).digest('hex') };
}

function isValidCanonicalQuestion(question) {
  return Boolean(
    question &&
      typeof question.sourceKey === 'string' &&
      question.sourceKey.trim() &&
      ['cpns', 'bumn'].includes(question.target) &&
      typeof question.category === 'string' &&
      question.category.trim() &&
      typeof question.prompt === 'string' &&
      question.prompt.trim() &&
      Array.isArray(question.options) &&
      question.options.length >= 2 &&
      question.options.length <= 6 &&
      question.options.every((option) => typeof option === 'string' && option.trim()) &&
      Number.isInteger(question.correctOptionIndex) &&
      question.correctOptionIndex >= 0 &&
      question.correctOptionIndex < question.options.length &&
      typeof question.explanation === 'string' &&
      question.explanation.trim(),
  );
}

function questionFingerprint(question) {
  return stableJson({
    target: String(question.target).trim().toLowerCase(),
    prompt: String(question.prompt).trim().replace(/\s+/g, ' ').toLowerCase(),
    options: Array.isArray(question.options) ? question.options.map((value) => String(value).trim().toLowerCase()) : [],
  });
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

class RestClient {
  constructor(baseUrl, secret) {
    this.endpoint = `${baseUrl}/rest/v1`;
    this.headers = { apikey: secret, authorization: `Bearer ${secret}`, 'content-type': 'application/json' };
  }

  async selectAll(table, columns) {
    const rows = [];
    for (let offset = 0; ; offset += 1000) {
      const response = await this.request(`${table}?select=${encodeURIComponent(columns)}&offset=${offset}&limit=1000`, { method: 'GET' });
      rows.push(...response);
      if (response.length < 1000) return rows;
    }
  }

  async upsert(table, rows, conflict) {
    if (rows.length === 0) return;
    for (let index = 0; index < rows.length; index += 100) {
      await this.request(`${table}?on_conflict=${encodeURIComponent(conflict)}`, {
        method: 'POST',
        headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
        body: JSON.stringify(rows.slice(index, index + 100)),
      });
    }
  }

  async update(table, id, row) {
    await this.request(`${table}?id=eq.${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify(row),
    });
  }

  async updateWhere(table, query, row) {
    await this.request(`${table}?${query}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify(row),
    });
  }

  async request(path, init) {
    const response = await fetch(`${this.endpoint}/${path}`, {
      ...init,
      headers: { ...this.headers, ...init.headers },
    });
    if (!response.ok) throw new Error(`Supabase ${init.method} ${path} failed (${response.status}): ${await response.text()}`);
    if (response.status === 204) return null;
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
}

async function load(relativePath) {
  return JSON.parse(await readFile(resolve(repositoryRoot, relativePath), 'utf8'));
}

function required(value, label) {
  if (!value?.trim()) throw new Error(`${label} is required.`);
  return value.trim();
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  syncContent().catch((error) => {
    process.stderr.write(`Content synchronization failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
