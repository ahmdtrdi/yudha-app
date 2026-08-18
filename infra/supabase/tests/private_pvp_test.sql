begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(16);

insert into public.profiles(
  id, username, target, rank_points, total_matches, wins, losses, coins
) values
  ('10000000-0000-0000-0000-000000000001', 'private-player-a', 'cpns', 420, 7, 4, 3, 90),
  ('10000000-0000-0000-0000-000000000002', 'private-player-b', 'cpns', 310, 5, 2, 3, 65);

create temporary table private_finalize_result as
select public.finalize_match_result(
  'room_private_pgtap',
  'private',
  'cpns',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  'player_a_win',
  'hp_zero',
  65,
  0,
  40,
  15,
  95,
  '2026-08-18 01:00:00+00'::timestamptz
) as payload;

select is(
  (select mode from public.match_results where room_id = 'room_private_pgtap'),
  'private',
  'Private mode is persisted'
);
select is(
  (select player_b_id from public.match_results where room_id = 'room_private_pgtap'),
  '10000000-0000-0000-0000-000000000002'::uuid,
  'Private match preserves the second human player'
);
select is(
  (select jsonb_build_array(rating_delta_a, rating_delta_b, coins_delta_a, coins_delta_b)
   from public.match_results where room_id = 'room_private_pgtap'),
  '[0, 0, 0, 0]'::jsonb,
  'Private match stores zero progression deltas'
);
select is(
  (select (payload ->> 'progressionApplied')::boolean from private_finalize_result),
  false,
  'Private finalization reports no progression'
);
select is(
  (select jsonb_build_array(rank_points, total_matches, wins, losses, coins)
   from public.profiles where id = '10000000-0000-0000-0000-000000000001'),
  '[420, 7, 4, 3, 90]'::jsonb,
  'Player A profile progression is unchanged'
);
select is(
  (select jsonb_build_array(rank_points, total_matches, wins, losses, coins)
   from public.profiles where id = '10000000-0000-0000-0000-000000000002'),
  '[310, 5, 2, 3, 65]'::jsonb,
  'Player B profile progression is unchanged'
);
select is((select count(*) from public.rank_point_transactions where source_id = 'room_private_pgtap'), 0::bigint, 'No rank ledger rows are created');
select is((select count(*) from public.coin_transactions where reference_id = 'room_private_pgtap'), 0::bigint, 'No coin ledger rows are created');
select is((select count(*) from public.daily_mission_progress where source_id = 'room_private_pgtap'), 0::bigint, 'No daily mission is completed');
select is((select count(*) from public.daily_learning_activity where source_id = 'room_private_pgtap'), 0::bigint, 'No streak activity is created');
select is((select count(*) from public.hired_pass_activity_events where source_id = 'room_private_pgtap'), 0::bigint, 'No Hired Pass activity is created');

create temporary table private_duplicate_result as
select public.finalize_match_result(
  'room_private_pgtap', 'private', 'cpns',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  'player_a_win', 'hp_zero', 65, 0, 40, 15, 95,
  '2026-08-18 01:00:00+00'::timestamptz
) as payload;

select is((select (payload ->> 'persisted')::boolean from private_duplicate_result), false, 'Duplicate finalization reports a replay');
select is((select count(*) from public.match_results where room_id = 'room_private_pgtap'), 1::bigint, 'Duplicate finalization does not insert twice');
select ok(has_function_privilege('service_role', 'public.finalize_match_result(text,text,text,uuid,uuid,uuid,uuid,text,text,integer,integer,integer,integer,integer,timestamp with time zone)', 'EXECUTE'), 'Backend role can finalize matches');
select ok(not has_function_privilege('authenticated', 'public.finalize_match_result(text,text,text,uuid,uuid,uuid,uuid,text,text,integer,integer,integer,integer,integer,timestamp with time zone)', 'EXECUTE'), 'Authenticated clients cannot finalize matches');
select ok(not has_function_privilege('authenticated', 'public.finalize_match_result(uuid,uuid,uuid,text,integer,integer,integer,integer,text,boolean)', 'EXECUTE'), 'Authenticated clients cannot call the legacy finalizer');

select * from finish();
rollback;
