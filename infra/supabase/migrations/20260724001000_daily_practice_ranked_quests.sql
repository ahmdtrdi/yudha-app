begin;

-- One completed practice session awards 50 Pass Points once per UTC day.
update public.hired_pass_missions
set
  title = 'Latihan harian',
  description = 'Selesaikan 1 sesi practice untuk mendapatkan 50 Pass Points',
  cadence = 'daily',
  target_count = 1,
  points_reward = 50,
  is_active = true
where id = '2026-07-practice-daily';

-- Replace the old weekly battle mission with a ranked-only daily mission.
update public.hired_pass_missions
set is_active = false
where id = '2026-07-battle-weekly';

insert into public.hired_pass_missions (
  id,
  season_id,
  title,
  description,
  event_type,
  cadence,
  target_count,
  points_reward,
  is_active
)
values (
  '2026-07-ranked-daily',
  '2026-07',
  'Ranked harian',
  'Selesaikan 1 ranked match untuk mendapatkan 50 Pass Points',
  'battle_completed',
  'daily',
  1,
  50,
  true
)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  event_type = excluded.event_type,
  cadence = excluded.cadence,
  target_count = excluded.target_count,
  points_reward = excluded.points_reward,
  is_active = excluded.is_active;

commit;
