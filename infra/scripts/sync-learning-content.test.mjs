import assert from 'node:assert/strict';
import test from 'node:test';
import { syncLearningContent } from './sync-learning-content.mjs';

test('learning content sync inserts immutable taxonomy, revisions, and mappings once', async () => {
  const client = mockClient({
    questions: [{ id: 'question-1', source_key: 'source-1' }],
  });
  const first = await syncLearningContent(client, taxonomy(), [bank()]);
  assert.equal(first.skills.inserted, 1);
  assert.equal(first.revisions.inserted, 1);
  assert.equal(first.revisions.mappingsInserted, 1);

  const replay = await syncLearningContent(client, taxonomy(), [bank()]);
  assert.equal(replay.skills.inserted, 0);
  assert.equal(replay.skills.skipped, 1);
  assert.equal(replay.revisions.inserted, 0);
  assert.equal(replay.revisions.skipped, 1);
  assert.equal(replay.revisions.mappingsInserted, 0);
  assert.equal(replay.revisions.mappingsSkipped, 1);
});

test('changed question content requires the next explicit revision', async () => {
  const client = mockClient({
    questions: [{ id: 'question-1', source_key: 'source-1' }],
  });
  await syncLearningContent(client, taxonomy(), [bank()]);

  const stale = bank();
  stale.questions[0].prompt = 'Changed prompt';
  await assert.rejects(
    syncLearningContent(client, taxonomy(), [stale]),
    /must declare revision 2/,
  );

  stale.questions[0].revision = 2;
  const changed = await syncLearningContent(client, taxonomy(), [stale]);
  assert.equal(changed.revisions.inserted, 1);
});

test('same taxonomy content version cannot be rewritten', async () => {
  const client = mockClient({
    questions: [{ id: 'question-1', source_key: 'source-1' }],
  });
  await syncLearningContent(client, taxonomy(), [bank()]);
  const drifted = taxonomy();
  drifted.effectiveAt = '2026-09-02T00:00:00.000Z';
  await assert.rejects(
    syncLearningContent(client, drifted, [bank()]),
    /Immutable taxonomy version differs/,
  );
});

function taxonomy() {
  return {
    schemaVersion: 1,
    contentVersion: 'development-test-v1',
    approvalStatus: 'development',
    smeApproved: false,
    approverReference: null,
    effectiveAt: '2026-09-01T00:00:00.000Z',
    targets: [
      {
        id: 'cpns',
        skills: [
          {
            id: 'cpns.tiu.verbal',
            category: 'tiu',
            subcategory: 'verbal',
            label: 'TIU Verbal',
            enabled: true,
            disabledReason: null,
            curriculumWeight: 1,
            prerequisiteSkillIds: [],
            required: true,
          },
        ],
      },
    ],
  };
}

function bank() {
  return {
    contentVersion: 'development-test-v1',
    questions: [
      {
        sourceKey: 'source-1',
        revision: 1,
        target: 'cpns',
        category: 'tiu',
        subcategory: 'verbal',
        primarySkillId: 'cpns.tiu.verbal',
        prerequisiteSkillIds: [],
        prompt: 'Prompt',
        options: ['A', 'B'],
        correctOptionIndex: 0,
        explanation: 'Explanation',
        hint: null,
        difficulty: 'easy',
        questionType: 'multiple_choice',
        expectedTimeMs: null,
        standardTimeLimitMs: 30000,
        curriculumWeight: 1,
        assessmentEligible: false,
        qualityState: 'development',
        active: true,
        smeApproved: false,
        approvedAt: null,
        approverReference: null,
      },
    ],
  };
}

function mockClient(initial) {
  const tables = new Map(
    Object.entries(initial).map(([table, rows]) => [
      table,
      structuredClone(rows),
    ]),
  );
  let sequence = 0;
  const rows = (table) => {
    const values = tables.get(table) ?? [];
    tables.set(table, values);
    return values;
  };
  return {
    async selectAll(table) {
      return structuredClone(rows(table));
    },
    async insert(table, values) {
      rows(table).push(...structuredClone(values));
    },
    async insertReturning(table, values) {
      const inserted = values.map((value) => ({
        id: `${table}-${++sequence}`,
        ...structuredClone(value),
      }));
      rows(table).push(...inserted);
      return structuredClone(inserted);
    },
  };
}
