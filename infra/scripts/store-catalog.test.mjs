import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { syncCatalog } from './sync-content.mjs';

const load = async (name) => JSON.parse(await readFile(
  new URL(`../../contracts/content/${name}.v1.json`, import.meta.url), 'utf8'));

test('every catalog exclusive matches the Pro selection policy', async () => {
  const catalog = await load('store-catalog');
  const policy = await load('economy-policy');
  assert.deepEqual(catalog.items.filter((item) => item.proExclusive).map((item) => item.id).sort(),
    [...policy.pro.exclusiveSkinIds].sort());
  assert.equal(catalog.items.find((item) => item.name === 'Opy').proExclusive, false);
  assert.equal(catalog.items.find((item) => item.name === 'Drakor').proExclusive, true);
});

test('catalog sync writes the current Pro column for every item', async () => {
  const catalog = await load('store-catalog');
  let written;
  await syncCatalog({ upsert: async (table, rows, key) => {
    assert.equal(table, 'store_items');
    assert.equal(key, 'id');
    written = rows;
  } }, catalog);
  assert.equal(written.length, catalog.items.length);
  for (const row of written) {
    assert.equal(row.is_pro_exclusive, catalog.items.find((item) => item.id === row.id).proExclusive);
    assert.equal('is_pass_exclusive' in row, false);
  }
});
