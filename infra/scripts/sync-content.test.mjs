import assert from 'node:assert/strict';
import test from 'node:test';
import { syncQuestions, toQuestionRow } from './sync-content.mjs';

test('clean import inserts and unchanged replay only skips', async () => {
  const client = mockClient([]);
  const bank = [question('legacy:cpns:1'), question('legacy:cpns:2')];
  assert.deepEqual(await syncQuestions(client, bank), {
    inserted: 2,
    updated: 0,
    skipped: 0,
    invalid: 0,
    duplicate: 0,
  });

  const existing = bank.map((item, index) => ({
    id: `db-${index}`,
    ...toQuestionRow(item),
  }));
  const replay = mockClient(existing);
  assert.deepEqual(await syncQuestions(replay, bank), {
    inserted: 0,
    updated: 0,
    skipped: 2,
    invalid: 0,
    duplicate: 0,
  });
  assert.equal(replay.upserts.length, 0);
  assert.equal(replay.updates.length, 0);
});

test('changed source updates and normalized legacy content reconciles', async () => {
  const changed = question('legacy:cpns:1', { prompt: 'Prompt terbaru' });
  const old = { id: 'db-1', ...toQuestionRow(question('legacy:cpns:1')) };
  const client = mockClient([old]);
  const result = await syncQuestions(client, [changed]);
  assert.equal(result.updated, 1);
  assert.equal(client.updates[0].id, 'db-1');

  const canonical = question('legacy:cpns:2');
  const legacy = {
    id: 'legacy-db-2',
    ...toQuestionRow(canonical),
    source_key: 'legacy-db:legacy-db-2',
  };
  const reconcile = mockClient([legacy]);
  const reconciled = await syncQuestions(reconcile, [canonical]);
  assert.equal(reconciled.updated, 1);
  assert.equal(reconcile.updates[0].row.source_key, canonical.sourceKey);
});

test('duplicates and invalid records are reported without partial writes', async () => {
  const canonical = question('legacy:cpns:1');
  const row = toQuestionRow(canonical);
  const client = mockClient([
    { id: 'legacy-a', ...row, source_key: 'legacy-db:a' },
    { id: 'legacy-b', ...row, source_key: 'legacy-db:b' },
  ]);
  const result = await syncQuestions(client, [
    canonical,
    question('legacy:cpns:2', { options: ['only-one'] }),
  ]);
  assert.equal(result.duplicate, 1);
  assert.equal(result.invalid, 1);
  assert.equal(client.updates.length, 0);
  assert.equal(client.upserts.length, 0);
});

function question(sourceKey, overrides = {}) {
  return {
    sourceKey,
    target: 'cpns',
    category: 'tiu',
    subcategory: 'verbal',
    prompt: 'Contoh pertanyaan',
    options: ['A', 'B', 'C', 'D'],
    correctOptionIndex: 1,
    explanation: 'Jawaban yang benar adalah "B".',
    difficulty: 'easy',
    weight: 1,
    effect: 'damage',
    damageValue: 10,
    healValue: 0,
    timeLimitSeconds: 30,
    hint: null,
    active: true,
    ...overrides,
  };
}

function mockClient(existing) {
  return {
    updates: [],
    upserts: [],
    async selectAll() {
      return structuredClone(existing);
    },
    async update(_table, id, row) {
      this.updates.push({ id, row });
    },
    async upsert(_table, rows) {
      this.upserts.push(...rows);
    },
  };
}
