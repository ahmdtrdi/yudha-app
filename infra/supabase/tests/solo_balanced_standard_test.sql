begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(11);

select has_table('public', 'solo_sessions', 'Solo sessions table exists');
select has_table('public', 'solo_session_questions', 'Solo question order table exists');
select has_table('public', 'solo_answers', 'Solo answers table exists');
select has_function('public', 'create_solo_session', array['uuid', 'text', 'text', 'text', 'integer', 'text'], 'Solo create RPC exists');
select has_function('public', 'open_solo_question', array['uuid', 'uuid', 'uuid', 'text'], 'Solo open RPC exists');
select has_function('public', 'submit_solo_answer', array['uuid', 'uuid', 'text', 'uuid', 'integer', 'boolean', 'timestamp with time zone'], 'Solo answer RPC exists');
select has_column('public', 'solo_answers', 'used_hint', 'Solo records hint use');
select has_function('public', 'finish_solo_session', array['uuid', 'uuid', 'text'], 'Solo stop RPC exists');
select ok(has_function_privilege('service_role', 'public.create_solo_session(uuid,text,text,text,integer,text)', 'EXECUTE'), 'backend role can create Solo sessions');
select ok(not has_function_privilege('authenticated', 'public.create_solo_session(uuid,text,text,text,integer,text)', 'EXECUTE'), 'mobile cannot mutate Solo directly');
select ok(not exists (
  select 1 from information_schema.check_constraints
  where constraint_name = 'coin_transactions_reason_check'
    and check_clause not like '%solo_reward%'
), 'coin ledger accepts Solo rewards');

select * from finish();
rollback;
