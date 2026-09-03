begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(17);

select has_table('public', 'solo_sessions', 'Solo sessions table exists');
select has_table('public', 'solo_session_questions', 'Solo question order table exists');
select has_table('public', 'solo_answers', 'Solo answers table exists');
select has_function('public', 'create_solo_session', array['uuid', 'text', 'text', 'text', 'integer', 'text'], 'Solo create RPC exists');
select has_function('public', 'open_solo_question', array['uuid', 'uuid', 'uuid', 'text'], 'Solo open RPC exists');
select has_function('public', 'request_solo_hint', array['uuid', 'uuid', 'uuid', 'text', 'timestamp with time zone'], 'Solo authoritative hint RPC exists');
select has_function('public', 'submit_solo_answer', array['uuid', 'uuid', 'text', 'uuid', 'integer', 'integer', 'integer', 'timestamp with time zone'], 'Solo Learning V2 answer RPC exists');
select has_function('public', 'reconcile_solo_session', array['uuid', 'uuid'], 'Solo timeout reconciliation RPC exists');
select has_column('public', 'solo_session_questions', 'hint_requested_at', 'Solo tracks hint requests on the server');
select has_column('public', 'solo_session_questions', 'question_revision_id', 'Solo snapshots the question revision');
select has_column('public', 'solo_answers', 'canonical_attempt_id', 'Solo answer links to canonical evidence');
select has_column('public', 'solo_sessions', 'policy_stop_trigger', 'Solo separates policy completion from its visible trigger');
select has_function('public', 'finish_solo_session', array['uuid', 'uuid', 'text'], 'Solo stop RPC exists');
select ok(has_function_privilege('service_role', 'public.create_solo_session(uuid,text,text,text,integer,text)', 'EXECUTE'), 'backend role can create Solo sessions');
select ok(not has_function_privilege('authenticated', 'public.create_solo_session(uuid,text,text,text,integer,text)', 'EXECUTE'), 'mobile cannot mutate Solo directly');
select ok(not has_function_privilege('authenticated', 'public.request_solo_hint(uuid,uuid,uuid,text,timestamp with time zone)', 'EXECUTE'), 'mobile cannot request Solo hints directly from the database');
select ok(not exists (
  select 1 from information_schema.check_constraints
  where constraint_name = 'coin_transactions_reason_check'
    and check_clause not like '%solo_reward%'
), 'coin ledger accepts Solo rewards');

select * from finish();
rollback;
