import { readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateHotsQuestion } from './hots-question-generators.mjs';
import { QUESTION_TAXONOMY } from './question-taxonomy.mjs';

export const MINIMUM_ACTIVE_QUESTIONS_PER_SUBCATEGORY = 150;
export const HOTS_SOURCE_PREFIX = 'hots-v1:';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..', '..');

export async function expandHotsQuestionBanks(root = repositoryRoot) {
  const reports = [];
  for (const target of Object.keys(QUESTION_TAXONOMY)) {
    const path = resolve(
      root,
      'contracts',
      'content',
      'questions',
      `${target}.v1.json`,
    );
    const bank = JSON.parse(await readFile(path, 'utf8'));
    const preserved = bank.questions.filter(
      (question) => !String(question.sourceKey).startsWith(HOTS_SOURCE_PREFIX),
    );
    const generated = [];
    for (const [category, subcategories] of Object.entries(
      QUESTION_TAXONOMY[target],
    )) {
      for (const subcategory of subcategories) {
        const existing = preserved.filter(
          (question) =>
            question.active
            && question.category === category
            && question.subcategory === subcategory,
        ).length;
        const required = Math.max(
          0,
          MINIMUM_ACTIVE_QUESTIONS_PER_SUBCATEGORY - existing,
        );
        const taxonomyPath = `${target}/${category}/${subcategory}`;
        for (let index = 1; index <= required; index += 1) {
          generated.push(generateHotsQuestion(taxonomyPath, index));
        }
        reports.push({
          target,
          category,
          subcategory,
          preserved: existing,
          generated: required,
          active: existing + required,
        });
      }
    }
    bank.questions = [...preserved, ...generated].sort(compareQuestions);
    validateExpandedBank(bank);
    await writeFile(path, `${JSON.stringify(bank, null, 2)}\n`, 'utf8');
  }
  return reports;
}

export function validateExpandedBank(bank) {
  const sourceKeys = new Set();
  const generatedFingerprints = new Set();
  const counts = new Map();
  for (const question of bank.questions) {
    if (sourceKeys.has(question.sourceKey)) {
      throw new Error(`Duplicate source key ${question.sourceKey}.`);
    }
    sourceKeys.add(question.sourceKey);
    if (question.active) {
      const path = `${question.category}/${question.subcategory}`;
      counts.set(path, (counts.get(path) ?? 0) + 1);
    }
    if (!String(question.sourceKey).startsWith(HOTS_SOURCE_PREFIX)) continue;
    if (question.prompt.trim().length < 60) {
      throw new Error(`HOTS prompt is too short: ${question.sourceKey}.`);
    }
    if (question.explanation.trim().length < 60) {
      throw new Error(`HOTS explanation is too short: ${question.sourceKey}.`);
    }
    const generatedText = [
      question.prompt,
      question.explanation,
      ...question.options,
    ].join(' ');
    if (/\b(?:undefined|NaN|Infinity)\b/i.test(generatedText)) {
      throw new Error(`HOTS question contains an unresolved value: ${question.sourceKey}.`);
    }
    if (question.options.length !== 4 || new Set(question.options).size !== 4) {
      throw new Error(`HOTS options must be four distinct values: ${question.sourceKey}.`);
    }
    if (
      question.correctOptionIndex < 0
      || question.correctOptionIndex >= question.options.length
    ) {
      throw new Error(`Invalid HOTS answer index: ${question.sourceKey}.`);
    }
    const fingerprint = normalizeText(question.prompt);
    if (generatedFingerprints.has(fingerprint)) {
      throw new Error(`Duplicate HOTS prompt: ${question.sourceKey}.`);
    }
    generatedFingerprints.add(fingerprint);
  }

  for (const [category, subcategories] of Object.entries(
    QUESTION_TAXONOMY[bank.target],
  )) {
    for (const subcategory of subcategories) {
      const path = `${category}/${subcategory}`;
      if ((counts.get(path) ?? 0) < MINIMUM_ACTIVE_QUESTIONS_PER_SUBCATEGORY) {
        throw new Error(`${bank.target}/${path} has fewer than 150 active questions.`);
      }
    }
  }
}

function compareQuestions(left, right) {
  const leftGenerated = String(left.sourceKey).startsWith(HOTS_SOURCE_PREFIX);
  const rightGenerated = String(right.sourceKey).startsWith(HOTS_SOURCE_PREFIX);
  if (leftGenerated !== rightGenerated) return leftGenerated ? 1 : -1;
  return String(left.sourceKey).localeCompare(String(right.sourceKey), 'en', {
    numeric: true,
  });
}

function normalizeText(value) {
  return String(value).trim().toLowerCase().replace(/\s+/g, ' ');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const report = await expandHotsQuestionBanks();
  const generated = report.reduce((sum, item) => sum + item.generated, 0);
  process.stdout.write(
    `${JSON.stringify({ generated, subcategories: report.length, report })}\n`,
  );
}
