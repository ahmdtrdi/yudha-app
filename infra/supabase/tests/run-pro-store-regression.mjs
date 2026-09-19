// In-memory database regression; never connects to a cloud database.
// node infra/supabase/tests/run-pro-store-regression.mjs <path-to-pglite/dist/index.js>
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const { PGlite } = await import(process.argv[2]
  ? pathToFileURL(resolve(process.argv[2])).href : '@electric-sql/pglite');
const db = new PGlite();
const read = async (path) => (await readFile(new URL(`../${path}`, import.meta.url), 'utf8')).replaceAll('\r\n', '\n');
const migration = await read('migrations/20260919120000_pro_exclusive_drakor.sql');
const economy = await read('migrations/20260902190000_economy_energy_yudha_pro.sql');
const remote = await read('migrations/20260817024104_remote_schema.sql');
const functionSql = (sql, startText) => {
  const start = sql.indexOf(startText);
  assert.notEqual(start, -1);
  const end = sql.indexOf('\n$$;', start);
  assert.notEqual(end, -1);
  return sql.slice(start, end + 4);
};
const user = '19191919-0000-0000-0000-000000000001';
const buyer = '19191919-0000-0000-0000-000000000002';
const rows = async (sql, params = []) => (await db.query(sql, params)).rows;

try {
  // Minimal hosting fixtures; execute the real migration and purchase/loadout RPCs.
  await db.exec(`
    create table store_items(id text primary key, type text, coin_price integer,
      is_active boolean, is_pro_exclusive boolean);
    create table economy_policy_versions(id text primary key, policy jsonb, is_active boolean);
    create table profiles(id uuid primary key, coins integer, equipped_avatar_id text,
      equipped_tower_id text, equipped_arena_id text);
    create table user_inventory(user_id uuid, item_id text, source text, source_ref text,
      primary key(user_id,item_id));
    create table store_purchases(id uuid default gen_random_uuid(), user_id uuid,
      item_id text, idempotency_key text, price_paid integer);
    create table coin_transactions(user_id uuid, delta integer, reason text,
      reference_id text, idempotency_key text, balance_after integer);
    insert into store_items values
      ('character-basic-pip','character_skin',500,true,true),
      ('character-legend-drakor','character_skin',2200,true,false),
      ('character-rare-brock','character_skin',1100,true,true),
      ('character-legend-luna','character_skin',2500,true,false);
    insert into economy_policy_versions values ('economy-v1',
      '{"pro":{"exclusiveSkinIds":["character-basic-pip","character-rare-brock"]},"other":"preserved"}', true);
  `);
  await db.query('insert into profiles values ($1,3000,$3,null,null),($2,3000,null,null,null)',
    [user, buyer, 'character-legend-drakor']);
  await db.query(`insert into user_inventory values
    ($1,'character-legend-drakor','purchase','old-purchase'),
    ($1,'character-basic-pip','pro','old-pro')`, [user]);
  const inventoryBefore = await rows('select * from user_inventory order by item_id');
  const profilesBefore = await rows('select * from profiles order by id');
  await db.exec(migration);
  await db.exec(migration);
  assert.deepEqual(await rows('select * from user_inventory order by item_id'), inventoryBefore);
  assert.deepEqual(await rows('select * from profiles order by id'), profilesBefore);
  const policy = (await rows('select policy from economy_policy_versions'))[0].policy;
  assert.deepEqual(policy.pro.exclusiveSkinIds, ['character-legend-drakor', 'character-rare-brock']);
  assert.equal(policy.other, 'preserved');
  const checks = await rows(await read('postchecks/20260919120000_pro_exclusive_drakor.sql'));
  assert.ok(checks.every((check) => check.passed), JSON.stringify(checks));

  await db.exec(functionSql(economy, 'create or replace function public.purchase_store_item('));
  await db.exec(functionSql(remote, 'CREATE OR REPLACE FUNCTION "public"."set_profile_loadout"('));
  const purchased = (await rows('select purchase_store_item($1,$2,$3) as result',
    [buyer, 'character-basic-pip', 'buy-opy']))[0].result;
  assert.equal(purchased.purchased, true);
  assert.equal(purchased.coins, 2500);
  for (const id of ['character-legend-drakor', 'character-rare-brock']) {
    await assert.rejects(db.query('select purchase_store_item($1,$2,$3)',
      [buyer, id, `buy-${id}`]), /YUDHA Pro exclusive/);
  }
  const equipped = (await rows('select set_profile_loadout($1,$2) as result',
    [user, 'character-legend-drakor']))[0].result;
  assert.equal(equipped.characterId, 'character-legend-drakor');
  assert.deepEqual(await rows('select * from user_inventory where user_id=$1 order by item_id', [user]), inventoryBefore);
  console.log('Passed: migration replay, ownership/loadout preservation, Pro policy, Opy purchase, exclusive purchase rejection, and existing-owner equip.');
} finally {
  await db.close();
}
