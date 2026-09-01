import assert from 'node:assert/strict';
import test from 'node:test';
import { runLegacyBackfill } from './learning-backfill.mjs';
import {
  invalidateLearningFixture,
  seedLearningFixture,
} from './learning-fixtures.mjs';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const TAXONOMY_ID = '22222222-2222-4222-8222-222222222222';

test('legacy Practice backfill dry-run is read-only and honest', async () => {
  const client = backfillClient();
  const report = await runLegacyBackfill(client, {
    source: 'practice',
    apply: false,
    runKey: 'practice-dry-1',
  });

  assert.equal(report.scanned, 1);
  assert.equal(report.wouldInsert, 1);
  assert.equal(report.inserted, 0);
  assert.equal(report.unsupportedProficiency, 1);
  assert.equal(client.tables.learning_attempts.length, 0);
  assert.equal(client.tables.learning_backfill_runs.length, 0);
});

test('legacy Practice apply and replay create one immutable attempt', async () => {
  const client = backfillClient();
  const first = await runLegacyBackfill(client, {
    source: 'practice',
    apply: true,
    runKey: 'practice-apply-1',
  });
  const replay = await runLegacyBackfill(client, {
    source: 'practice',
    apply: true,
    runKey: 'practice-apply-1',
  });

  assert.equal(first.inserted, 1);
  assert.equal(first.replayed, false);
  assert.equal(replay.replayed, true);
  assert.equal(client.tables.learning_attempts.length, 1);
  assert.equal(
    client.tables.learning_attempts[0].source_attempt_key,
    'practice:answer-1',
  );
  assert.equal(client.tables.learning_attempt_classifications.length, 1);
  assert.equal(
    client.tables.learning_attempt_classifications[0]
      .valid_for_unseen_independent_accuracy,
    false,
  );
});

test('fixture commands require an exact disposable-user confirmation', async () => {
  await assert.rejects(
    seedLearningFixture(new FakeClient({}), {
      userId: USER_ID,
      confirmDisposable: '33333333-3333-4333-8333-333333333333',
      runKey: 'fixture-1',
      scenario: 'mixed',
    }),
    /exactly match/,
  );
});

test('mixed fixture seed/replay/invalidation is idempotent without deleting ledger rows', async () => {
  const client = fixtureClient();
  const first = await seedLearningFixture(client, {
    userId: USER_ID,
    confirmDisposable: USER_ID,
    runKey: 'fixture-mixed-1',
    scenario: 'mixed',
    baseTime: '2026-09-01T00:00:00.000Z',
  });
  const replay = await seedLearningFixture(client, {
    userId: USER_ID,
    confirmDisposable: USER_ID,
    runKey: 'fixture-mixed-1',
    scenario: 'mixed',
  });
  const invalidated = await invalidateLearningFixture(client, {
    userId: USER_ID,
    confirmDisposable: USER_ID,
    runKey: 'fixture-mixed-1',
    reason: 'test cleanup',
  });
  const invalidationReplay = await invalidateLearningFixture(client, {
    userId: USER_ID,
    confirmDisposable: USER_ID,
    runKey: 'fixture-mixed-1',
    reason: 'test cleanup',
  });

  assert.equal(first.attempts, 39);
  assert.equal(replay.replayed, true);
  assert.equal(replay.attempts, 39);
  assert.equal(invalidated.invalidated, 39);
  assert.equal(invalidationReplay.replayed, true);
  assert.equal(client.tables.learning_attempts.length, 39);
  assert.equal(client.tables.learning_attempt_invalidations.length, 39);
  assert.ok(client.rpcCalls.length >= 8);
});

function backfillClient() {
  return new FakeClient({
    practice_answers: [
      {
        id: 'answer-1',
        session_id: 'session-1',
        user_id: USER_ID,
        question_id: 'question-1',
        selected_option_index: 2,
        is_correct: true,
        answered_at: '2026-08-01T00:00:00.000Z',
        canonical_attempt_id: null,
      },
    ],
    practice_sessions: [
      {
        id: 'session-1',
        user_id: USER_ID,
        target: 'cpns',
        category: 'tiu',
        subcategory: 'numerik',
        started_at: '2026-08-01T00:00:00.000Z',
        finished_at: '2026-08-01T00:05:00.000Z',
      },
    ],
    learning_attempts: [],
    learning_attempt_classifications: [],
    learning_backfill_runs: [],
  });
}

function fixtureClient() {
  const skills = Array.from({ length: 4 }, (_, index) => ({
    taxonomy_version_id: TAXONOMY_ID,
    skill_id: `cpns.skill.${index + 1}`,
    target: 'cpns',
    category: `category-${index + 1}`,
    subcategory: null,
    label: `Skill ${index + 1}`,
    enabled: true,
    curriculum_weight: 1,
    is_required: true,
  }));
  const revisions = [];
  const mappings = [];
  for (let skillIndex = 0; skillIndex < 4; skillIndex += 1) {
    for (let item = 0; item < 20; item += 1) {
      const id = `revision-${skillIndex + 1}-${item + 1}`;
      revisions.push({
        id,
        question_id: `question-${skillIndex + 1}-${item + 1}`,
        content_version: 'development-2026-08',
        category: `category-${skillIndex + 1}`,
        subcategory: null,
        difficulty: item % 2 === 0 ? 'easy' : 'medium',
        correct_option_index: item % 4,
        expected_time_ms: null,
        standard_time_limit_ms: 30_000,
        curriculum_weight: 1,
        quality_state: 'development',
        is_active: true,
      });
      mappings.push({
        question_revision_id: id,
        taxonomy_version_id: TAXONOMY_ID,
        skill_id: skills[skillIndex].skill_id,
        mapping_type: 'primary',
      });
    }
  }
  return new FakeClient({
    profiles: [{ id: USER_ID, target: 'cpns' }],
    learning_taxonomy_versions: [
      {
        id: TAXONOMY_ID,
        effective_at: '2026-09-01T00:00:00.000Z',
        created_at: '2026-09-01T00:00:00.000Z',
      },
    ],
    learning_skills: skills,
    question_skill_mappings: mappings,
    question_revisions: revisions,
    learning_fixture_runs: [],
    learning_attempts: [],
    learning_attempt_classifications: [],
    learner_question_exposures: [],
    learning_attempt_invalidations: [],
  });
}

class FakeClient {
  constructor(tables) {
    this.tables = new Proxy(tables, {
      get(target, property) {
        if (!target[property]) target[property] = [];
        return target[property];
      },
    });
    this.sequence = 0;
    this.rpcCalls = [];
  }

  async selectAll(table, _columns, filters = '') {
    return this.tables[table]
      .filter((row) => matches(row, filters))
      .map((row) => structuredClone(row));
  }

  async insertReturning(table, rows) {
    return rows.map((row) => {
      const stored = {
        id: row.id ?? this.nextId(),
        created_at: row.created_at ?? '2026-09-01T00:00:00.000Z',
        ...structuredClone(row),
      };
      this.tables[table].push(stored);
      return structuredClone(stored);
    });
  }

  async insert(table, rows) {
    this.tables[table].push(...rows.map((row) => structuredClone(row)));
  }

  async upsert(table, rows, conflict) {
    const keys = conflict.split(',');
    for (const row of rows) {
      const existing = this.tables[table].find((candidate) =>
        keys.every((key) => candidate[key] === row[key]),
      );
      if (existing) Object.assign(existing, structuredClone(row));
      else this.tables[table].push(structuredClone(row));
    }
  }

  async updateWhere(table, query, row) {
    for (const candidate of this.tables[table]) {
      if (matches(candidate, query)) Object.assign(candidate, structuredClone(row));
    }
  }

  async rpc(name, body) {
    this.rpcCalls.push({ name, body: structuredClone(body) });
    return null;
  }

  nextId() {
    this.sequence += 1;
    return `00000000-0000-4000-8000-${String(this.sequence).padStart(12, '0')}`;
  }
}

function matches(row, filters) {
  if (!filters) return true;
  return filters.split('&').every((filter) => {
    const separator = filter.indexOf('=');
    const key = filter.slice(0, separator);
    const operation = decodeURIComponent(filter.slice(separator + 1));
    if (operation === 'is.null') return row[key] == null;
    if (operation === 'not.is.null') return row[key] != null;
    if (operation.startsWith('eq.')) {
      const expected = operation.slice(3);
      if (expected === 'true') return row[key] === true;
      if (expected === 'false') return row[key] === false;
      return String(row[key]) === expected;
    }
    if (operation.startsWith('in.(')) {
      const values = operation.slice(4, -1).split(',');
      return values.includes(String(row[key]));
    }
    return true;
  });
}
