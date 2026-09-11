-- Solo is the current Practice experience. Record completion in the same
-- transaction as the session result, including games finished via timeout.
begin;

create or replace function public.record_solo_daily_mission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed' and new.finished_at is not null then
    insert into public.daily_mission_progress (
      user_id, mission_key, business_date, source_type, source_id,
      completed_at, reward_rank_points, reward_ycoins
    ) values (
      new.user_id, 'daily_practice', public.wib_business_date(new.finished_at),
      'solo', new.id::text, new.finished_at, 0, 0
    ) on conflict (user_id, mission_key, business_date) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.record_solo_daily_mission() from public, anon, authenticated;
grant execute on function public.record_solo_daily_mission() to service_role;

drop trigger if exists solo_daily_mission_completion on public.solo_sessions;
create trigger solo_daily_mission_completion
after insert or update of status on public.solo_sessions
for each row execute function public.record_solo_daily_mission();

-- Repair previously completed Solo sessions without replaying game rewards.
insert into public.daily_mission_progress (
  user_id, mission_key, business_date, source_type, source_id,
  completed_at, reward_rank_points, reward_ycoins
)
select distinct on (user_id, public.wib_business_date(finished_at))
  user_id, 'daily_practice', public.wib_business_date(finished_at),
  'solo', id::text, finished_at, 0, 0
from public.solo_sessions
where status = 'completed' and finished_at is not null
order by user_id, public.wib_business_date(finished_at), finished_at, id
on conflict (user_id, mission_key, business_date) do nothing;

commit;
