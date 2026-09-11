// Standalone in-memory PostgreSQL regression runner; never loads .env or uses cloud credentials.
// node infra/supabase/tests/run-solo-learning-regression.mjs <path-to-pglite/dist/index.js>
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';

const { PGlite } = await import(process.argv[2]
  ? pathToFileURL(resolve(process.argv[2])).href : '@electric-sql/pglite');
const db = new PGlite();
const read = async (name) => (await readFile(new URL(`../${name}`, import.meta.url), 'utf8')).replaceAll('\r\n', '\n');
const migration = await read('migrations/20260910130000_restore_solo_learning_ingestion.sql');
const recovery = await read('recovery/20260910130000_backfill_solo_learning.sql');
const base = await read('bootstrapv2.sql');
const foundation = await read('migrations/20260901090000_learning_v2_analytics_foundation.sql');
const gate = await read('migrations/20260817050000_gate_0_1_learning_foundation.sql');
const solo = await read('migrations/20260901090000_solo_balanced_standard.sql');
const alignment = await read('migrations/20260902120000_solo_learning_v2_alignment.sql');
const mechanics = await read('migrations/20260903150000_solo_focus_speed_mechanics.sql');
const table = (sql, name) => {
  const match = sql.match(new RegExp(`create table if not exists public\\.${name} \\([\\s\\S]*?\n\\);`, 'i'));
  assert.ok(match, `DDL exists for ${name}`);
  return match[0];
};
const fn = (sql, name) => {
  const start = sql.indexOf(`create or replace function public.${name}(`);
  assert.notEqual(start, -1, `function exists: ${name}`);
  const end = sql.indexOf('\n$$;', start);
  assert.notEqual(end, -1);
  return sql.slice(start, end + 4);
};
const row = async (sql, params = []) => (await db.query(sql, params)).rows[0];
const count = async (name) => Number((await row(`select count(*) as n from public.${name}`)).n);

try {
  // Load the real production table definitions and constraints. Only Supabase
  // auth and pgcrypto hosting facilities are substituted in this WASM harness.
  await db.exec(`
    create schema auth; create schema extensions;
    create role anon; create role authenticated; create role service_role;
    create table auth.users(id uuid primary key);
    create function extensions.digest(value text, algorithm text) returns bytea
      language sql immutable as $$ select sha256(convert_to(value, 'UTF8')) $$;
  `);
  await db.exec(fn(gate, 'valid_question_options'));
  await db.exec(fn(gate, 'wib_business_date'));
  for (const name of ['profiles', 'questions']) await db.exec(table(base, name));
  for (const name of ['learning_taxonomy_versions', 'learning_skills', 'question_revisions',
    'learner_question_exposures', 'learning_fixture_runs', 'learning_recommendations',
    'learning_attempts', 'learning_attempt_classifications', 'learning_attempt_invalidations',
    'learning_projection_jobs']) await db.exec(table(foundation, name));
  for (const name of ['solo_sessions', 'solo_session_questions', 'solo_answers']) await db.exec(table(solo, name));
  await db.exec(`create unique index solo_sessions_one_active_per_user_idx
    on public.solo_sessions(user_id) where status = 'active';`);
  await db.exec(table(gate, 'api_idempotency_records'));
  const remote = await read('migrations/20260817024104_remote_schema.sql');
  await db.exec(remote.match(/CREATE TABLE IF NOT EXISTS "public"\."coin_transactions" \([\s\S]*?\n\);/)[0]);
  await db.exec(`alter table public.coin_transactions drop constraint coin_transactions_reason_check;
    alter table public.coin_transactions add primary key (id);
    create unique index coin_test_idempotency on public.coin_transactions(user_id,idempotency_key);
    alter table public.solo_answers add column used_hint boolean not null default false;`);
  await db.exec(alignment.slice(alignment.indexOf('alter table public.solo_sessions'), alignment.indexOf('create or replace function public.solo_session_payload')));
  await db.exec(mechanics.slice(mechanics.indexOf('alter table public.solo_sessions'), mechanics.indexOf('drop function')));
  await db.exec(fn(alignment, 'solo_session_payload'));
  await db.exec(fn(foundation, 'enqueue_learning_projection'));
  await db.exec(fn(foundation, 'queue_learning_attempt_projection'));
  await db.exec(fn(foundation, 'reject_learning_attempt_mutation'));
  await db.exec(fn(foundation, 'reject_learning_classification_mutation'));
  await db.exec(`
    create trigger learning_attempts_projection_queue after insert on public.learning_attempts
      for each row execute function public.queue_learning_attempt_projection();
    create trigger learning_attempts_append_only_guard before update or delete on public.learning_attempts
      for each row execute function public.reject_learning_attempt_mutation();
    create trigger learning_classifications_append_only_guard before update or delete on public.learning_attempt_classifications
      for each row execute function public.reject_learning_classification_mutation();
  `);
  const indexStart = foundation.indexOf('create unique index if not exists learning_projection_jobs_pending_unique_idx');
  await db.exec(foundation.slice(indexStart, foundation.indexOf(';', indexStart) + 1));

  const user = randomUUID();
  const taxonomy = randomUUID();
  await db.query('insert into auth.users values ($1)', [user]);
  await db.query("insert into public.profiles(id,username,target) values ($1,'sql-test','cpns')", [user]);
  await db.query(`insert into public.learning_taxonomy_versions(id,schema_version,content_version,approval_status)
    values ($1,1,'sql-test','development')`, [taxonomy]);
  await db.query(`insert into public.learning_skills(taxonomy_version_id,skill_id,target,category,label)
    values ($1,'test-skill','cpns','tiu','Test')`, [taxonomy]);
  const questions = [];
  for (let i = 0; i < 20; i++) {
    const q = randomUUID(), revision = randomUUID();
    await db.query(`insert into public.questions(id,target,category,prompt,options,correct_option_index)
      values ($1,'cpns','tiu','Question','["A","B","C","D"]',0)`, [q]);
    await db.query(`insert into public.question_revisions(id,question_id,revision,source_key,content_version,content_hash,
      target,category,prompt,options,correct_option_index,explanation,difficulty,standard_time_limit_ms)
      values ($1,$2::uuid,1,($2::uuid)::text,'sql-test',($2::uuid)::text,'cpns','tiu','Question','["A","B","C","D"]',0,'Explanation','easy',60000)`, [revision,q]);
    questions.push({ q, revision });
  }
  async function session(mode, { legacy = false, hinted = false, seen = false } = {}) {
    await db.exec(`update public.solo_sessions set status='stopped', completion_reason='user_stopped'
      where status='active';`);
    const id = randomUUID();
    const sqs = [];
    await db.query(`insert into public.solo_sessions(id,user_id,target,mechanic_mode,question_selection,
      question_count,character_id,requested_mechanic_mode,effective_mechanic_mode)
      values ($1,$2,'cpns',$3,'balanced',20,'test-character',$3,$3)`, [id,user,mode]);
    for (const [i, q] of questions.entries()) {
      const sq = randomUUID();
      await db.query(`insert into public.solo_session_questions(id,session_id,question_id,question_order,
        question_revision_id,taxonomy_version_id,skill_id,exposure_count_before,seen_before,opened_at,deadline_at,hint_requested_at)
        values ($1,$2,$3,$4,$5,$6,$7,$8,$9,'2026-09-10T00:00:00Z',$10,$11)`,
      [sq,id,q.q,i+1,legacy ? null : q.revision,legacy ? null : taxonomy,legacy ? null : 'test-skill',
        legacy ? null : Number(seen),legacy ? null : seen,mode === 'focus' ? null : '2026-09-10T00:01:00Z',
        hinted ? '2026-09-10T00:00:01Z' : null]);
      sqs.push(sq);
    }
    return { id, sqs };
  }
  const submit = async (s, i = 0, { key = `answer-${s.id}-${i}`, active = 1000, background = 0,
    time = '2026-09-10T00:00:02Z', selected = 0 } = {}) => (await row(
    'select public.submit_solo_answer($1,$2,$3,$4,$5,$6,$7,$8) as result',
    [user,s.id,key,s.sqs[i],selected,active,background,time])).result;
  const attempt = async (id) => row('select * from public.learning_attempts where id=$1', [id]);
  const classification = async (id) => row('select * from public.learning_attempt_classifications where attempt_id=$1', [id]);

  // Reproduce the actual regression using the previous deployed function.
  await db.exec(fn(mechanics, 'submit_solo_answer'));
  const broken = await session('standard');
  const brokenResponse = await submit(broken);
  assert.equal(brokenResponse.attemptId, null);
  assert.equal(await count('solo_answers'), 1);
  assert.equal(await count('learning_attempts'), 0);

  // Install the exact migration twice to exercise manual SQL reruns.
  await db.exec(migration);
  await db.exec(migration);
  const repairedReplay = await submit(broken);
  assert.ok(repairedReplay.attemptId);
  assert.equal(await count('solo_answers'), 1);
  assert.equal(await count('learning_attempts'), 1);
  assert.equal(repairedReplay.answeredCount, brokenResponse.answeredCount);
  assert.equal((await attempt(repairedReplay.attemptId)).skill_id, 'test-skill');
  console.log('PASS: reproduced missing evidence; migration and cached replay restore it');

  for (const mode of ['standard', 'focus', 'speed']) {
    const s = await session(mode);
    const result = await submit(s);
    const a = await attempt(result.attemptId);
    assert.equal(a.data_fidelity, 'v2_complete');
    assert.equal(a.effective_mechanic_mode, mode);
    assert.equal(a.skill_id, 'test-skill');
    assert.equal(a.deadline_at === null, mode === 'focus');
    assert.equal((await classification(a.id)).valid_for_unseen_independent_accuracy, true);
    assert.ok((await row(`select id from public.learning_projection_jobs
      where user_id=$1 and taxonomy_version_id=$2 and skill_id='test-skill' and status='pending'`, [user,taxonomy])).id);
    const before = await count('learning_attempts');
    assert.deepEqual(await submit(s), result);
    assert.equal((await submit(s, 0, { key: `new-key-${s.id}` })).attemptId, a.id);
    assert.equal(await count('learning_attempts'), before);
    await assert.rejects(submit(s, 0, { selected: 1 }), /IDEMPOTENCY_KEY_REUSED/);
  }
  console.log('PASS: all mechanics persist classified evidence; duplicate submissions create no extra rows');

  const hinted = await session('focus', { hinted: true });
  const hintResult = await submit(hinted);
  assert.equal((await classification(hintResult.attemptId)).valid_for_assisted_accuracy, true);
  assert.equal((await classification(hintResult.attemptId)).valid_for_unseen_independent_accuracy, false);
  const seen = await session('standard', { seen: true });
  assert.equal((await classification((await submit(seen)).attemptId)).valid_for_unseen_independent_accuracy, false);
  const invalidTime = await session('speed');
  const invalid = await attempt((await submit(invalidTime, 0, { active: 9000 })).attemptId);
  assert.equal(invalid.timing_invalidity_reason, 'client_active_time_exceeds_server_elapsed');
  assert.equal((await classification(invalid.id)).valid_for_pace_analytics, false);
  const timeout = await session('speed');
  const timedOut = await attempt((await submit(timeout, 0, { time: '2026-09-10T00:01:01Z', selected: null })).attemptId);
  assert.equal(timedOut.timed_out, true);
  assert.equal(timedOut.is_correct, false);
  console.log('PASS: hints, exposure, invalid timing, and timeouts retain evidence exclusions');

  const completed = await session('standard');
  const coinsBefore = (await row('select coins from public.profiles where id=$1',[user])).coins;
  let last;
  for (let i = 0; i < 20; i++) last = await submit(completed, i);
  assert.equal(last.status, 'completed');
  assert.equal(last.rewardCoins, 10);
  assert.equal((await attempt(last.attemptId)).session_completion_state, 'policy_completed');
  assert.equal(Number((await row('select count(*) as n from public.learning_attempts where source_session_key=$1',[completed.id])).n), 20);
  assert.equal((await row('select coins from public.profiles where id=$1',[user])).coins, coinsBefore + 10);
  await submit(completed, 19);
  assert.equal((await row('select coins from public.profiles where id=$1',[user])).coins, coinsBefore + 10);
  console.log('PASS: completing 20 answers writes 20 attempts and awards coins once');

  // Use the production mission table with the later nullable reward ledger
  // columns. The rank ledger is irrelevant to these zero-reward missions.
  await db.exec(table(gate, 'daily_mission_progress')
    .replace(' references public.rank_point_transactions(id)', ''));
  const elo = await read('migrations/20260902160000_pvp_analytics_elo.sql');
  const missionDdl = elo.indexOf('alter table public.daily_mission_progress');
  await db.exec(elo.slice(missionDdl, elo.indexOf('create or replace function public.apply_daily_mission', missionDdl)));
  const missions = await read('migrations/20260911100000_solo_daily_mission_completion.sql');
  const missionCoins = (await row('select coins from public.profiles where id=$1', [user])).coins;
  await db.exec(missions);
  await db.exec(missions);
  assert.equal(await count('daily_mission_progress'), 1);
  assert.equal((await row('select source_id from public.daily_mission_progress')).source_id, completed.id);
  assert.equal((await row('select coins from public.profiles where id=$1', [user])).coins, missionCoins);
  const secondCompleted = await session('focus');
  for (let i = 0; i < 20; i++) await submit(secondCompleted, i);
  assert.equal(await count('daily_mission_progress'), 1);
  const tomorrow = await session('speed');
  for (let i = 0; i < 20; i++) await submit(tomorrow, i, { time: '2026-09-11T18:00:00Z', selected: null });
  assert.equal(await count('daily_mission_progress'), 2);
  assert.equal((await row(`select business_date::text as day from public.daily_mission_progress where source_id=$1`, [tomorrow.id])).day, '2026-09-12');
  const stopped = await session('standard');
  await db.query(`update public.solo_sessions set status='stopped', completion_reason='user_stopped', finished_at='2026-09-13T00:00:00Z' where id=$1`, [stopped.id]);
  assert.equal(await count('daily_mission_progress'), 2);
  assert.equal((await row('select sum(reward_rank_points + reward_ycoins) as n from public.daily_mission_progress')).n, 0);
  console.log('PASS: Solo missions backfill once, complete atomically for all modes, respect WIB days, and exclude stopped sessions');

  const atomic = await session('standard');
  const answersBeforeFailure = await count('solo_answers');
  await db.exec(`create function public.reject_test_evidence() returns trigger language plpgsql
    as $$ begin raise exception 'test evidence failure'; end; $$;
    create trigger reject_test_evidence before insert on public.learning_attempts
      for each row execute function public.reject_test_evidence();`);
  await assert.rejects(submit(atomic), /test evidence failure/);
  assert.equal(await count('solo_answers'), answersBeforeFailure);
  assert.equal((await row('select answered_count from public.solo_sessions where id=$1',[atomic.id])).answered_count, 0);
  await db.exec('drop trigger reject_test_evidence on public.learning_attempts; drop function public.reject_test_evidence();');
  assert.ok((await submit(atomic)).attemptId);
  console.log('PASS: ingestion failures roll back the answer and session update atomically');

  // Simulate more production answers written by the broken function, then
  // recover them alongside pre-alignment rows with genuinely missing metadata.
  await db.exec(fn(mechanics, 'submit_solo_answer'));
  const old = await session('focus');
  await submit(old);
  const legacy = await session('standard', { legacy: true });
  await db.query(`insert into public.solo_answers(session_id,session_question_id,user_id,question_id,
    selected_option_index,is_correct,correct_option_index_snapshot,explanation_snapshot,answered_at)
    values ($1,$2,$3,$4,0,true,0,'Explanation','2026-09-10T00:00:02Z')`, [legacy.id,legacy.sqs[0],user,questions[0].q]);
  await db.exec(migration);
  // Exercise repair of an existing ledger row whose link/classification is
  // missing, with the append-only guard enabled for the actual recovery.
  await db.exec("select set_config('app.learning_maintenance','on',false)");
  await db.query('delete from public.learning_attempt_classifications where attempt_id=$1', [hintResult.attemptId]);
  await db.exec("select set_config('app.learning_maintenance','off',false)");
  await db.query('update public.solo_answers set canonical_attempt_id=null where canonical_attempt_id=$1', [hintResult.attemptId]);
  const preservedAttempt = JSON.stringify(await attempt(hintResult.attemptId));
  const beforeRecovery = { coins: (await row('select coins from public.profiles where id=$1',[user])).coins,
    answers: await count('solo_answers'), exposures: await count('learner_question_exposures'),
    sessions: JSON.stringify((await db.query('select * from public.solo_sessions order by id')).rows) };
  await db.exec(recovery);
  assert.equal(JSON.stringify(await attempt(hintResult.attemptId)), preservedAttempt);
  assert.equal((await classification(hintResult.attemptId)).valid_for_assisted_accuracy, true);
  const recovered = await row('select * from public.learning_attempts where source_session_key=$1', [old.id]);
  assert.equal(recovered.data_fidelity, 'v2_complete');
  const legacyAttempt = await row('select * from public.learning_attempts where source_session_key=$1', [legacy.id]);
  assert.equal(legacyAttempt.data_fidelity, 'legacy_solo');
  assert.equal(legacyAttempt.skill_id, null);
  assert.equal(legacyAttempt.taxonomy_version_id, null);
  assert.equal((await classification(legacyAttempt.id)).valid_for_unseen_independent_accuracy, false);
  const ledger = JSON.stringify((await db.query('select * from public.learning_attempts order by id')).rows);
  const classes = JSON.stringify((await db.query('select * from public.learning_attempt_classifications order by attempt_id')).rows);
  await db.exec(recovery);
  assert.equal(JSON.stringify((await db.query('select * from public.learning_attempts order by id')).rows), ledger);
  assert.equal(JSON.stringify((await db.query('select * from public.learning_attempt_classifications order by attempt_id')).rows), classes);
  assert.equal(await count('solo_answers'), beforeRecovery.answers);
  assert.equal(await count('learner_question_exposures'), beforeRecovery.exposures);
  assert.equal((await row('select coins from public.profiles where id=$1',[user])).coins, beforeRecovery.coins);
  assert.equal(JSON.stringify((await db.query('select * from public.solo_sessions order by id')).rows), beforeRecovery.sessions);
  const checks = await db.exec(await read('postchecks/20260910130000_restore_solo_learning_ingestion.sql'));
  assert.deepEqual(checks[0].rows, []);
  await assert.rejects(db.query('update public.learning_attempts set skill_id=skill_id'), /LEARNING_ATTEMPTS_APPEND_ONLY/);
  const privileges = await row(`select has_function_privilege('authenticated',
    'public.ingest_solo_answer_learning_evidence(uuid)', 'EXECUTE') as allowed`);
  assert.equal(privileges.allowed, false);
  assert.equal((await row(`select has_function_privilege('service_role',
    'public.ingest_solo_answer_learning_evidence(uuid)', 'EXECUTE') as allowed`)).allowed, true);
  console.log('PASS: recovery is idempotent, legacy metadata stays unknown, gameplay balances stay unchanged, postchecks pass');
} catch (error) {
  console.error('FAIL:', error.message, error.detail ?? '', error.where ?? '', error.query ?? '');
  process.exitCode = 1;
} finally {
  await db.close();
}
