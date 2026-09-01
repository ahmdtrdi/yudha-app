import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  normalizeQuestionTaxonomy,
  QUESTION_TAXONOMY_CONTENT_VERSION,
} from './question-taxonomy.mjs';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..', '..');
const outputDirectory = resolve(repositoryRoot, 'contracts', 'content', 'questions');

const sources = [
  {
    target: 'cpns',
    input: resolve(repositoryRoot, 'apps', 'games', 'data', 'questions.json'),
    output: resolve(outputDirectory, 'cpns.v1.json'),
    mapTopic(type) {
      if (type === 'twk') return { category: 'twk', subcategory: null };
      return { category: 'tiu', subcategory: type };
    },
  },
  {
    target: 'bumn',
    input: resolve(repositoryRoot, 'apps', 'games', 'data', 'quesitons_bumn.json'),
    output: resolve(outputDirectory, 'bumn.v1.json'),
    mapTopic(type) {
      if (type === 'kepribadian_bumn') {
        return { category: 'akhlak', subcategory: null };
      }
      return {
        category: 'tkd',
        subcategory: type.replace(/_bumn$/, ''),
      };
    },
  },
];

export async function generateCanonicalQuestions() {
  await mkdir(outputDirectory, { recursive: true });
  const counts = {};
  for (const source of sources) {
    const legacy = JSON.parse(await readFile(source.input, 'utf8'));
    const existing = await loadExistingQuestions(source.output);
    const existingBySource = new Map(
      existing.map((question) => [question.sourceKey, question]),
    );
    const generated = legacy.map((record) => {
      const question = normalizeRecord(source, record);
      const previous = existingBySource.get(question.sourceKey);
      return previous ? { ...question, revision: previous.revision } : question;
    });
    const retained = existing.filter(
      (question) => !String(question.sourceKey).startsWith(`legacy:${source.target}:`),
    );
    const questions = [...generated, ...retained]
      .map(normalizeQuestionTaxonomy)
      .sort(compareSourceKeys);
    const bank = {
      schemaVersion: 1,
      contentVersion: QUESTION_TAXONOMY_CONTENT_VERSION,
      approvalStatus: 'development',
      smeApproved: false,
      approverReference: null,
      target: source.target,
      questions,
    };
    await writeFile(source.output, `${JSON.stringify(bank, null, 2)}\n`, 'utf8');
    counts[source.target] = questions.length;
  }
  return counts;
}

export async function mergeRemoteQuestions(environment = process.env) {
  await mkdir(outputDirectory, { recursive: true });
  const baseUrl = required(environment.SUPABASE_URL, 'SUPABASE_URL').replace(
    /\/$/,
    '',
  );
  const secret = required(
    environment.SUPABASE_SECRET_KEY ?? environment.SUPABASE_SERVICE_ROLE_KEY,
    'SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY',
  );
  const columns = [
    'source_key',
    'target',
    'category',
    'subcategory',
    'prompt',
    'options',
    'correct_option_index',
    'explanation',
    'difficulty',
    'weight',
    'effect',
    'damage_value',
    'heal_value',
    'time_limit_seconds',
    'hint',
    'is_active',
  ].join(',');
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const response = await fetch(
      `${baseUrl}/rest/v1/questions?select=${encodeURIComponent(columns)}&offset=${offset}&limit=1000`,
      {
        headers: {
          apikey: secret,
          authorization: `Bearer ${secret}`,
          'user-agent': 'yudha-server-question-contract-sync/1.0',
        },
      },
    );
    if (!response.ok) {
      throw new Error(
        `Question download failed (${response.status}): ${await response.text()}`,
      );
    }
    const batch = await response.json();
    rows.push(...batch);
    if (batch.length < 1000) break;
  }

  const counts = {};
  for (const target of ['cpns', 'bumn']) {
    const output = resolve(outputDirectory, `${target}.v1.json`);
    const existing = await loadExistingQuestions(output);
    const existingBySource = new Map(
      existing.map((question) => [question.sourceKey, question]),
    );
    const questions = rows
      .filter((row) => row.target === target)
      .map((row) =>
        toContractQuestion(row, existingBySource.get(row.source_key)),
      )
      .map(normalizeQuestionTaxonomy)
      .sort(compareSourceKeys);
    const bank = {
      schemaVersion: 1,
      contentVersion: QUESTION_TAXONOMY_CONTENT_VERSION,
      approvalStatus: 'development',
      smeApproved: false,
      approverReference: null,
      target,
      questions,
    };
    await writeFile(output, `${JSON.stringify(bank, null, 2)}\n`, 'utf8');
    counts[target] = questions.length;
  }
  return counts;
}

function normalizeRecord(source, record) {
  const optionKeys = ['a', 'b', 'c', 'd'];
  const options = optionKeys.map((key) => String(record.option?.[key] ?? '').trim());
  const correctOptionIndex = optionKeys.indexOf(String(record.correct_answer).toLowerCase());
  const numericId = Number(record.id);
  const topic = source.mapTopic(String(record.tipe).toLowerCase());
  const effect = numericId % 4 === 0 ? 'heal' : 'damage';
  const weight = Math.min(4, Math.max(1, Number(record.point_kesulitan) || 1));
  const difficulty = weight === 1 ? 'easy' : weight === 2 ? 'medium' : 'hard';
  const correctOption = options[correctOptionIndex] ?? '';
  const primarySkillId = [source.target, topic.category, topic.subcategory]
    .filter(Boolean)
    .join('.');

  return normalizeQuestionTaxonomy({
    sourceKey: `legacy:${source.target}:${record.id}`,
    revision: 1,
    target: source.target,
    category: topic.category,
    subcategory: topic.subcategory,
    primarySkillId,
    prerequisiteSkillIds: [],
    prompt: String(record.question ?? '').trim(),
    options,
    correctOptionIndex,
    explanation: `Jawaban yang benar adalah "${correctOption}".`,
    difficulty,
    questionType: 'multiple_choice',
    expectedTimeMs: null,
    standardTimeLimitMs: 30000,
    curriculumWeight: 1,
    assessmentEligible: false,
    qualityState: 'development',
    smeApproved: false,
    approvedAt: null,
    approverReference: null,
    weight,
    effect,
    damageValue: effect === 'damage' ? 10 : 0,
    healValue: effect === 'heal' ? 10 : 0,
    timeLimitSeconds: 30,
    hint: null,
    active: true,
  });
}

function toContractQuestion(row, existing) {
  return {
    sourceKey: row.source_key,
    revision: existing?.revision ?? 1,
    target: row.target,
    category: row.category,
    subcategory: row.subcategory,
    primarySkillId: existing?.primarySkillId ?? '',
    prerequisiteSkillIds: existing?.prerequisiteSkillIds ?? [],
    prompt: row.prompt,
    options: row.options,
    correctOptionIndex: Number(row.correct_option_index),
    explanation: row.explanation,
    difficulty: row.difficulty,
    questionType: existing?.questionType ?? 'multiple_choice',
    expectedTimeMs: existing?.expectedTimeMs ?? null,
    standardTimeLimitMs:
      existing?.standardTimeLimitMs ?? Number(row.time_limit_seconds) * 1000,
    curriculumWeight: existing?.curriculumWeight ?? 1,
    assessmentEligible: existing?.assessmentEligible ?? false,
    qualityState: existing?.qualityState ?? 'development',
    smeApproved: existing?.smeApproved ?? false,
    approvedAt: existing?.approvedAt ?? null,
    approverReference: existing?.approverReference ?? null,
    weight: Number(row.weight),
    effect: row.effect,
    damageValue: Number(row.damage_value),
    healValue: Number(row.heal_value),
    timeLimitSeconds: Number(row.time_limit_seconds),
    hint: row.hint,
    active: row.is_active,
  };
}

async function loadExistingQuestions(path) {
  try {
    const bank = JSON.parse(await readFile(path, 'utf8'));
    return Array.isArray(bank.questions) ? bank.questions : [];
  } catch (error) {
    if (error?.code === 'ENOENT') return [];
    throw error;
  }
}

function compareSourceKeys(left, right) {
  const leftNumber = Number(String(left.sourceKey).split(':').at(-1));
  const rightNumber = Number(String(right.sourceKey).split(':').at(-1));
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber)) {
    return leftNumber - rightNumber;
  }
  return String(left.sourceKey).localeCompare(String(right.sourceKey));
}

function required(value, label) {
  if (!value) throw new Error(`${label} is required.`);
  return value;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mergeRemote = process.argv.includes('--merge-remote');
  const counts = mergeRemote
    ? await mergeRemoteQuestions()
    : await generateCanonicalQuestions();
  process.stdout.write(
    `${mergeRemote ? 'Merged remote' : 'Generated'} CPNS=${counts.cpns} BUMN=${counts.bumn}\n`,
  );
}
