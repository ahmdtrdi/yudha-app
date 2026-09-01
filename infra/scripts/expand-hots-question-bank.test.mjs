import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import {
  HOTS_SOURCE_PREFIX,
  MINIMUM_ACTIVE_QUESTIONS_PER_SUBCATEGORY,
  validateExpandedBank,
} from './expand-hots-question-bank.mjs';

for (const target of ['cpns', 'bumn']) {
  test(`${target} bank has 150 active questions per subcategory`, async () => {
    const bank = JSON.parse(
      await readFile(`../contracts/content/questions/${target}.v1.json`, 'utf8'),
    );
    validateExpandedBank(bank);
    const generated = bank.questions.filter((question) =>
      question.sourceKey.startsWith(HOTS_SOURCE_PREFIX),
    );
    assert.ok(generated.length > 0);
    assert.ok(generated.every((question) => question.active));
    assert.ok(
      generated.every(
        (question) => question.standardTimeLimitMs >= 75000,
      ),
    );
    const distribution = Object.groupBy(
      bank.questions.filter((question) => question.active),
      (question) => `${question.category}/${question.subcategory}`,
    );
    assert.ok(
      Object.values(distribution).every(
        (questions) =>
          questions.length >= MINIMUM_ACTIVE_QUESTIONS_PER_SUBCATEGORY,
      ),
    );
  });
}

test('generated HOTS prompts do not contain redundant selection prefixes', async () => {
  const banks = await Promise.all(
    ['cpns', 'bumn'].map(async (target) => JSON.parse(
      await readFile(`../contracts/content/questions/${target}.v1.json`, 'utf8'),
    )),
  );
  let generatedCount = 0;
  for (const question of banks.flatMap((bank) => bank.questions)) {
    if (!question.sourceKey.startsWith(HOTS_SOURCE_PREFIX)) continue;
    generatedCount += 1;
    assert.doesNotMatch(
      question.prompt,
      /dalam konteks seleksi (?:CPNS|BUMN)/i,
      question.sourceKey,
    );
    assert.doesNotMatch(
      question.prompt,
      /^(?:(?:dalam|pada|untuk) (?:studi|latihan|kasus|penjadwalan|analisis|skenario|simulasi|rekap|pola|proyek)|memo evaluasi)\b.*\bke-\d+/i,
      question.sourceKey,
    );
    assert.equal(question.options.length, 4);
    assert.equal(new Set(question.options).size, 4);
    assert.ok(question.options[question.correctOptionIndex]);
    assert.equal(question.qualityState, 'development');
    assert.equal(question.smeApproved, false);
  }
  assert.equal(generatedCount, 2778);
});
