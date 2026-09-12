-- Read-only verification of the deployed Solo configuration.
with functions as (
  select proname, pg_get_functiondef(p.oid) as definition
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and proname in ('create_solo_session', 'open_solo_question')
)
select
  (select definition like '%p_question_count not in (10, 20, 30)%'
   from functions where proname = 'create_solo_session') as new_counts_10_20_30,
  (select definition like '%v_effective_time_sec := 40;%'
      and definition like '%v_effective_time_sec := 20;%'
      and definition like '%v_effective_time_sec := 0;%'
      and definition like '%v_sq.deadline_at := null;%'
   from functions where proname = 'open_solo_question') as fixed_timers_and_untimed_focus,
  (select pg_get_constraintdef(oid) like '%ARRAY[10, 20, 30, 35, 50]%'
   from pg_constraint where conrelid = 'public.solo_sessions'::regclass
     and conname = 'solo_sessions_question_count_check') as historical_counts_preserved,
  not exists (select 1 from public.solo_sessions
    where question_count not in (10, 20, 30, 35, 50)) as stored_counts_valid,
  not has_function_privilege('authenticated',
    'public.open_solo_question(uuid,uuid,uuid,text)', 'EXECUTE')
    and has_function_privilege('service_role',
    'public.open_solo_question(uuid,uuid,uuid,text)', 'EXECUTE') as rpc_permissions_preserved;
