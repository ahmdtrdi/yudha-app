begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(15);

select is(public.wib_business_date('2026-08-16 16:59:59+00'::timestamptz), '2026-08-16'::date, 'WIB date before midnight');
select is(public.wib_business_date('2026-08-16 17:00:00+00'::timestamptz), '2026-08-17'::date, 'WIB date at midnight');
select is(public.wib_week_start('2026-08-16 17:00:00+00'::timestamptz), '2026-08-17'::date, 'WIB week starts Monday');
select is(public.rank_tier(399), 'rookie', 'Rookie upper boundary');
select is(public.rank_tier(1200), 'legend', 'Legend lower boundary');
select has_table('public', 'api_idempotency_records', 'idempotency table exists');
select has_table('public', 'practice_session_completions', 'Practice completion table exists');
select has_table('public', 'rank_point_transactions', 'rank ledger exists');
select has_table('public', 'daily_mission_progress', 'daily mission table exists');
select has_table('public', 'daily_learning_activity', 'streak activity table exists');
select ok(public.valid_question_options('["A", "B"]'::jsonb), 'two question options are valid');
select ok(not public.valid_question_options('["A"]'::jsonb), 'one question option is invalid');
select ok(has_function_privilege('service_role', 'public.create_practice_session(uuid,text,text)', 'EXECUTE'), 'backend role can create Practice sessions');
select ok(not has_function_privilege('authenticated', 'public.create_practice_session(uuid,text,text)', 'EXECUTE'), 'authenticated role cannot mutate Practice directly');
select ok(not has_function_privilege('authenticated', 'public.get_user_leaderboard_rank(uuid)', 'EXECUTE'), 'my-rank SQL is backend-only');

select * from finish();
rollback;
