begin;

-- Streaks are earned only by a completed Solo session or a normal public PvP
-- match. Practice still completes its daily mission but must not create a
-- streak day.
alter table public.practice_session_completions
  alter column last_streak_date drop not null;

create or replace function public.apply_streak_activity(
  p_user_id uuid,
  p_source_type text,
  p_source_id text,
  p_completed_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_date date := public.wib_business_date(p_completed_at);
  v_inserted boolean := false;
  v_current integer;
  v_best integer;
  v_last date;
begin
  select current_streak, best_streak, last_streak_date
  into v_current, v_best, v_last
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;

  if p_source_type not in ('solo', 'ranked', 'casual') then
    return jsonb_build_object(
      'created', false,
      'current', v_current,
      'best', v_best,
      'lastDate', v_last
    );
  end if;

  insert into public.daily_learning_activity
    (user_id, business_date, source_type, source_id, completed_at)
  values (p_user_id, v_date, p_source_type, p_source_id, p_completed_at)
  on conflict (user_id, business_date) do nothing;
  v_inserted := found;

  if v_inserted and (v_last is null or v_date > v_last) then
    v_current := case
      when v_last = v_date - 1 then v_current + 1
      else 1
    end;
    v_best := greatest(v_best, v_current);
    v_last := v_date;

    update public.profiles
    set current_streak = v_current,
        best_streak = v_best,
        last_streak_date = v_last,
        updated_at = p_completed_at
    where id = p_user_id;
  end if;

  return jsonb_build_object(
    'created', v_inserted,
    'current', v_current,
    'best', v_best,
    'lastDate', v_last
  );
end;
$$;

create or replace function public.record_completed_solo_streak()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_streak jsonb;
begin
  if old.status is distinct from 'completed'
      and new.status = 'completed'
      and new.completion_reason = 'policy_completed' then
    v_streak := public.apply_streak_activity(
      new.user_id,
      'solo',
      new.id::text,
      coalesce(new.finished_at, clock_timestamp())
    );

    if (v_streak ->> 'created')::boolean then
      perform public.record_hired_pass_activity(
        new.user_id,
        'streak_day_created',
        new.id::text,
        coalesce(new.finished_at, clock_timestamp())
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists solo_completed_streak on public.solo_sessions;
create trigger solo_completed_streak
after update of status, completion_reason on public.solo_sessions
for each row execute function public.record_completed_solo_streak();

revoke all on function public.record_completed_solo_streak() from public, anon, authenticated;

-- Rebuild the derived streak-day ledger from authoritative completed Solo and
-- public PvP records. This also removes historical Practice-only streak days.
create temporary table streak_qualifying_activity on commit drop as
with candidates as (
  select
    result.player_a_id as user_id,
    public.wib_business_date(result.ended_at) as business_date,
    result.mode as source_type,
    result.room_id as source_id,
    result.ended_at as completed_at
  from public.match_results result
  where result.player_a_id is not null
    and result.mode in ('ranked', 'casual')
    and result.reason in ('hp_zero', 'round_timeout', 'question_exhaustion', 'draw')

  union all

  select
    result.player_b_id,
    public.wib_business_date(result.ended_at),
    result.mode,
    result.room_id,
    result.ended_at
  from public.match_results result
  where result.player_b_id is not null
    and result.mode in ('ranked', 'casual')
    and result.reason in ('hp_zero', 'round_timeout', 'question_exhaustion', 'draw')

  union all

  select
    session.user_id,
    public.wib_business_date(session.finished_at),
    'solo',
    session.id::text,
    session.finished_at
  from public.solo_sessions session
  where session.status = 'completed'
    and session.completion_reason = 'policy_completed'
    and session.finished_at is not null
)
select distinct on (user_id, business_date)
  user_id,
  business_date,
  source_type,
  source_id,
  completed_at
from candidates
order by user_id, business_date, completed_at, source_type, source_id;

delete from public.daily_learning_activity;

insert into public.daily_learning_activity
  (user_id, business_date, source_type, source_id, completed_at)
select user_id, business_date, source_type, source_id, completed_at
from streak_qualifying_activity;

with ordered_days as (
  select
    user_id,
    business_date,
    business_date - row_number() over (
      partition by user_id order by business_date
    )::integer as run_key
  from streak_qualifying_activity
), runs as (
  select
    user_id,
    run_key,
    count(*)::integer as run_length,
    max(business_date) as run_end
  from ordered_days
  group by user_id, run_key
), latest_runs as (
  select distinct on (user_id)
    user_id,
    run_length,
    run_end
  from runs
  order by user_id, run_end desc
), best_runs as (
  select user_id, max(run_length)::integer as best_length
  from runs
  group by user_id
)
update public.profiles profile
set current_streak = latest.run_length,
    best_streak = best.best_length,
    last_streak_date = latest.run_end,
    updated_at = clock_timestamp()
from latest_runs latest
join best_runs best on best.user_id = latest.user_id
where profile.id = latest.user_id;

update public.profiles profile
set current_streak = 0,
    best_streak = 0,
    last_streak_date = null,
    updated_at = clock_timestamp()
where not exists (
  select 1
  from streak_qualifying_activity activity
  where activity.user_id = profile.id
);

commit;
