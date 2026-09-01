import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';
import {
  repositoryRoot,
  validateQuestionBank,
  validateSeason,
  validateSeasons,
  validateStoreCatalog,
} from './validate-gate0.mjs';

const load = async (path) =>
  JSON.parse(await readFile(resolve(repositoryRoot, path), 'utf8'));

test('rejects duplicate question source keys', async () => {
  const [bank, taxonomy] = await Promise.all([
    load('contracts/content/questions/cpns.v1.json'),
    load('contracts/content/taxonomy.v1.json'),
  ]);
  bank.questions[1].sourceKey = bank.questions[0].sourceKey;
  assert.throws(() => validateQuestionBank(bank, taxonomy), /Duplicate cpns sourceKey ID/);
});

test('rejects question mappings to unknown skills', async () => {
  const [bank, taxonomy] = await Promise.all([
    load('contracts/content/questions/cpns.v1.json'),
    load('contracts/content/taxonomy.v1.json'),
  ]);
  bank.questions[0].primarySkillId = 'cpns.tiu.unknown';
  assert.throws(
    () => validateQuestionBank(bank, taxonomy),
    /Unknown or disabled primary skill/,
  );
});

test('rejects duplicate Store item IDs', async () => {
  const catalog = await load('contracts/content/store-catalog.v1.json');
  catalog.items[1].id = catalog.items[0].id;
  assert.throws(() => validateStoreCatalog(catalog), /Duplicate store item ID/);
});

test('rejects overlapping seasons', async () => {
  const [manifest, catalog] = await Promise.all([
    load('contracts/content/seasons/2026-08.development.json'),
    load('contracts/content/store-catalog.v1.json'),
  ]);
  const next = structuredClone(manifest);
  next.season.id = 'beta-2026-08-overlap';
  next.releaseActive = false;
  assert.throws(() => validateSeasons([manifest, next], catalog), /overlaps/);
});

test('rejects premium cosmetic pairs that are not Pass-exclusive', async () => {
  const [manifest, catalog] = await Promise.all([
    load('contracts/content/seasons/2026-08.development.json'),
    load('contracts/content/store-catalog.v1.json'),
  ]);
  const pip = catalog.items.find((item) => item.id === 'character-basic-pip');
  pip.passExclusive = false;
  const pair = manifest.rewards.find(
    (reward) => reward.track === 'premium' && reward.itemId === pip.id,
  );
  pair.coins = manifest.rewards.find(
    (reward) => reward.track === 'free' && reward.pointsRequired === pair.pointsRequired,
  ).coins;
  assert.throws(() => validateSeason(manifest, catalog), /not superior/);
});

test('rejects unreachable reward milestones', async () => {
  const [manifest, catalog] = await Promise.all([
    load('contracts/content/seasons/2026-08.development.json'),
    load('contracts/content/store-catalog.v1.json'),
  ]);
  for (const reward of manifest.rewards) reward.pointsRequired += 100000;
  assert.throws(() => validateSeason(manifest, catalog), /cannot reach/);
});
