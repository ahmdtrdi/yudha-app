begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(26);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.learning_attempts'::regclass
      and conname = 'learning_attempts_fixture_run_id_fkey'
      and confdeltype = 'r'
  ),
  'fixture-run deletion cannot cascade into the canonical evidence ledger'
);

select has_column(
  'public', 'learner_skill_state', 'difficulty_level_count',
  'prepared state stores confidence diversity input'
);
select has_column(
  'public', 'learner_skill_state', 'latest_strong_evidence_at',
  'prepared state stores strong-evidence freshness'
);
select has_index(
  'public', 'question_skill_mappings',
  'question_skill_mappings_one_primary_idx',
  'one primary mapping index exists'
);
select ok(
  pg_get_indexdef('public.question_skill_mappings_one_primary_idx'::regclass)
    like '%question_revision_id, taxonomy_version_id%',
  'one primary mapping is scoped by taxonomy version'
);
select has_trigger(
  'public', 'profiles', 'profiles_learning_projection_queue',
  'new profiles enqueue initial learning projections'
);

select ok(
  to_regprocedure('public.create_practice_session_learning_v2(uuid,text,text,uuid)') is not null,
  'Learning V2 Practice creation RPC exists'
);
select ok(
  to_regprocedure('public.request_practice_hint_learning_v2(uuid,uuid,uuid,text,timestamptz)') is not null,
  'authoritative hint RPC exists'
);
select ok(
  to_regprocedure('public.submit_practice_answer_learning_v2(uuid,uuid,text,uuid,integer,integer,timestamptz)') is not null,
  'atomic Practice/canonical-attempt answer RPC exists'
);
select ok(
  to_regprocedure('public.finish_practice_session_learning_v2(uuid,uuid,text,timestamptz)') is not null,
  'Learning V2 completion attribution RPC exists'
);
select ok(
  to_regprocedure('public.claim_learning_projection_jobs(text,integer,timestamptz)') is not null,
  'projection job claim RPC exists'
);
select ok(
  to_regprocedure('public.ingest_pvp_learning_evidence(uuid)') is not null,
  'idempotent PvP canonical ingestion RPC exists'
);
select ok(
  to_regprocedure('public.reconcile_recent_pvp_learning_evidence(timestamptz,integer)') is not null,
  'scheduled PvP reconciliation RPC exists'
);

select ok(
  has_function_privilege('service_role', 'public.create_practice_session_learning_v2(uuid,text,text,uuid)', 'EXECUTE'),
  'service role can create Learning V2 Practice sessions'
);
select ok(
  has_function_privilege('service_role', 'public.request_practice_hint_learning_v2(uuid,uuid,uuid,text,timestamptz)', 'EXECUTE'),
  'service role can serve authoritative hints'
);
select ok(
  has_function_privilege('service_role', 'public.submit_practice_answer_learning_v2(uuid,uuid,text,uuid,integer,integer,timestamptz)', 'EXECUTE'),
  'service role can atomically ingest compatibility evidence'
);
select ok(
  has_function_privilege('service_role', 'public.finish_practice_session_learning_v2(uuid,uuid,text,timestamptz)', 'EXECUTE'),
  'service role can finalize compatibility attribution'
);
select ok(
  has_function_privilege('service_role', 'public.claim_learning_projection_jobs(text,integer,timestamptz)', 'EXECUTE'),
  'service role can claim projection jobs'
);
select ok(
  has_function_privilege('service_role', 'public.ingest_pvp_learning_evidence(uuid)', 'EXECUTE'),
  'service role can ingest authoritative PvP source evidence'
);
select ok(
  has_function_privilege('service_role', 'public.reconcile_recent_pvp_learning_evidence(timestamptz,integer)', 'EXECUTE'),
  'service role can reconcile missed PvP ingestion'
);

select ok(
  not has_function_privilege('authenticated', 'public.create_practice_session_learning_v2(uuid,text,text,uuid)', 'EXECUTE'),
  'authenticated clients cannot call Learning V2 creation RPC directly'
);
select ok(
  not has_function_privilege('authenticated', 'public.request_practice_hint_learning_v2(uuid,uuid,uuid,text,timestamptz)', 'EXECUTE'),
  'authenticated clients cannot bypass backend hint authority'
);
select ok(
  not has_function_privilege('authenticated', 'public.submit_practice_answer_learning_v2(uuid,uuid,text,uuid,integer,integer,timestamptz)', 'EXECUTE'),
  'authenticated clients cannot write canonical attempts directly'
);
select ok(
  not has_function_privilege('authenticated', 'public.claim_learning_projection_jobs(text,integer,timestamptz)', 'EXECUTE'),
  'authenticated clients cannot claim projection jobs'
);
select ok(
  not has_function_privilege('authenticated', 'public.ingest_pvp_learning_evidence(uuid)', 'EXECUTE'),
  'authenticated clients cannot ingest PvP evidence directly'
);
select ok(
  not has_function_privilege('authenticated', 'public.reconcile_recent_pvp_learning_evidence(timestamptz,integer)', 'EXECUTE'),
  'authenticated clients cannot run PvP reconciliation'
);

select * from finish();
rollback;
