import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const ROOT = new URL('../../', import.meta.url);

test('Learning V2 OpenAPI and fixtures evolve together without removing legacy analytics', async () => {
  const openapi = await json('contracts/openapi/yudha-api.v1.json');
  const dashboard = await json(
    'contracts/fixtures/learning-v2-dashboard-mixed.json',
  );
  const recommendation = await json(
    'contracts/fixtures/learning-v2-recommendation-current.json',
  );
  const hint = await json('contracts/fixtures/learning-v2-practice-hint.json');
  const lobby = await json('contracts/fixtures/gate1/lobby-summary.json');

  assert.ok(openapi.paths['/analytics']);
  assert.ok(openapi.paths['/learning/dashboard']);
  assert.ok(openapi.paths['/learning/recommendations/current']);
  assert.ok(
    openapi.paths['/learning/recommendations/{recommendationId}/events'],
  );
  assert.ok(
    openapi.paths[
      '/practice/sessions/{id}/questions/{sessionQuestionId}/hint'
    ],
  );
  assert.equal(dashboard.data.calculationVersion, 'learning-v1');
  assert.equal(dashboard.data.summary.pace.value, null);
  assert.equal(dashboard.data.assessment.status, 'not_available');
  assert.equal(
    recommendation.data.availability.compatibilityAdapter,
    'practice_fixed_five',
  );
  assert.equal(typeof hint.data.hint, 'string');
  assert.equal(lobby.data.learningNextAction, null);
});

async function json(relativePath) {
  return JSON.parse(await readFile(new URL(relativePath, ROOT), 'utf8'));
}
