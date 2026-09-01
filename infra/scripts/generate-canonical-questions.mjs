import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

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
    const questions = legacy.map((record) => normalizeRecord(source, record));
    const bank = {
      schemaVersion: 1,
      contentVersion: 'development-2026-08',
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

  return {
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
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const counts = await generateCanonicalQuestions();
  process.stdout.write(`Generated CPNS=${counts.cpns} BUMN=${counts.bumn}\n`);
}
