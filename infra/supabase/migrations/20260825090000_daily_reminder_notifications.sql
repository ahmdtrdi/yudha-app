create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  enabled boolean not null default false,
  morning_enabled boolean not null default true,
  morning_time time without time zone not null default time '09:00',
  rescue_enabled boolean not null default true,
  rescue_time time without time zone not null default time '19:30',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.push_installations (
  user_id uuid not null references public.profiles(id) on delete cascade,
  installation_id uuid not null,
  fcm_token text not null,
  platform text not null,
  time_zone text not null,
  authorized boolean not null default true,
  active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, installation_id),
  constraint push_installations_platform_check check (platform in ('android', 'web')),
  constraint push_installations_token_length_check check (char_length(fcm_token) between 20 and 4096),
  constraint push_installations_time_zone_length_check check (char_length(time_zone) between 1 and 100)
);

create unique index if not exists push_installations_fcm_token_unique
  on public.push_installations(fcm_token);
create index if not exists push_installations_active_idx
  on public.push_installations(active, authorized, last_seen_at desc);

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  installation_id uuid not null,
  kind text not null,
  local_date date not null,
  business_date date not null,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  lease_until timestamptz,
  expires_at timestamptz not null,
  fcm_message_id text,
  last_error text,
  sent_at timestamptz,
  opened_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_delivery_dedupe_unique
    unique (user_id, installation_id, kind, local_date),
  constraint notification_deliveries_kind_check check (kind in ('morning', 'rescue')),
  constraint notification_deliveries_status_check check (
    status in ('pending', 'processing', 'sent', 'failed', 'cancelled')
  ),
  constraint notification_deliveries_attempt_count_check check (attempt_count between 0 and 3)
);

create index if not exists notification_deliveries_claim_idx
  on public.notification_deliveries(status, next_attempt_at, lease_until)
  where status in ('pending', 'processing');

alter table public.notification_preferences enable row level security;
alter table public.push_installations enable row level security;
alter table public.notification_deliveries enable row level security;

revoke all on public.notification_preferences,
  public.push_installations,
  public.notification_deliveries from public, anon, authenticated;
grant all on public.notification_preferences,
  public.push_installations,
  public.notification_deliveries to service_role;

create or replace function public.claim_due_notification_deliveries(
  p_now timestamptz default clock_timestamp(),
  p_limit integer default 100
)
returns table (
  delivery_id uuid,
  user_id uuid,
  installation_id uuid,
  fcm_token text,
  platform text,
  time_zone text,
  kind text,
  local_date date,
  business_date date,
  current_streak integer,
  remaining_mission_keys text[],
  expires_at timestamptz,
  attempt_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_date date := public.wib_business_date(p_now);
  v_expires_at timestamptz := ((v_business_date + 1)::timestamp at time zone 'Asia/Jakarta');
begin
  if p_limit < 1 or p_limit > 500 then
    raise exception using errcode = '22023', message = 'p_limit must be between 1 and 500';
  end if;

  insert into public.notification_deliveries (
    user_id, installation_id, kind, local_date, business_date, expires_at
  )
  select
    i.user_id,
    i.installation_id,
    'morning',
    local_clock.local_date,
    v_business_date,
    v_expires_at
  from public.push_installations i
  join public.notification_preferences preferences on preferences.user_id = i.user_id
  cross join lateral (
    select
      timezone(i.time_zone, p_now) as local_now,
      timezone(i.time_zone, p_now)::date as local_date
  ) local_clock
  where preferences.enabled
    and preferences.morning_enabled
    and i.active
    and i.authorized
    and i.last_seen_at >= p_now - interval '30 days'
    and local_clock.local_now >= local_clock.local_date + preferences.morning_time
    and local_clock.local_now < local_clock.local_date + preferences.morning_time + interval '15 minutes'
    and (
      select count(*)
      from public.daily_mission_progress mission
      where mission.user_id = i.user_id
        and mission.business_date = v_business_date
    ) < 2
  on conflict on constraint notification_delivery_dedupe_unique do nothing;

  insert into public.notification_deliveries (
    user_id, installation_id, kind, local_date, business_date, expires_at
  )
  select
    i.user_id,
    i.installation_id,
    'rescue',
    local_clock.local_date,
    v_business_date,
    v_expires_at
  from public.push_installations i
  join public.notification_preferences preferences on preferences.user_id = i.user_id
  join public.profiles profile on profile.id = i.user_id
  cross join lateral (
    select
      timezone(i.time_zone, p_now) as local_now,
      timezone(i.time_zone, p_now)::date as local_date
  ) local_clock
  where preferences.enabled
    and preferences.rescue_enabled
    and i.active
    and i.authorized
    and i.last_seen_at >= p_now - interval '30 days'
    and profile.current_streak > 0
    and profile.last_streak_date = v_business_date - 1
    and not exists (
      select 1
      from public.daily_learning_activity activity
      where activity.user_id = i.user_id
        and activity.business_date = v_business_date
    )
    and local_clock.local_now >= local_clock.local_date + preferences.rescue_time
    and local_clock.local_now < local_clock.local_date + preferences.rescue_time + interval '15 minutes'
  on conflict on constraint notification_delivery_dedupe_unique do nothing;

  update public.notification_deliveries delivery
  set status = 'cancelled', updated_at = p_now
  where delivery.status in ('pending', 'processing')
    and delivery.expires_at <= p_now;

  return query
  with claimed as (
    select delivery.id
    from public.notification_deliveries delivery
    join public.push_installations claim_installation
      on claim_installation.user_id = delivery.user_id
      and claim_installation.installation_id = delivery.installation_id
    join public.notification_preferences claim_preferences
      on claim_preferences.user_id = delivery.user_id
    where (
        (delivery.status = 'pending' and delivery.next_attempt_at <= p_now)
        or (delivery.status = 'processing' and delivery.lease_until <= p_now)
      )
      and claim_preferences.enabled
      and case delivery.kind
        when 'morning' then claim_preferences.morning_enabled
        when 'rescue' then claim_preferences.rescue_enabled
        else false
      end
      and claim_installation.active
      and claim_installation.authorized
      and claim_installation.last_seen_at >= p_now - interval '30 days'
      and delivery.attempt_count < 3
      and delivery.expires_at > p_now
      and case delivery.kind
        when 'morning' then (
          select count(*)
          from public.daily_mission_progress mission
          where mission.user_id = delivery.user_id
            and mission.business_date = delivery.business_date
        ) < 2
        when 'rescue' then exists (
          select 1
          from public.profiles profile
          where profile.id = delivery.user_id
            and profile.current_streak > 0
            and profile.last_streak_date = delivery.business_date - 1
            and not exists (
              select 1
              from public.daily_learning_activity activity
              where activity.user_id = delivery.user_id
                and activity.business_date = delivery.business_date
            )
        )
        else false
      end
    order by delivery.next_attempt_at, delivery.created_at
    limit p_limit
    for update skip locked
  ), leased as (
    update public.notification_deliveries delivery
    set status = 'processing',
        attempt_count = delivery.attempt_count + 1,
        lease_until = p_now + interval '5 minutes',
        updated_at = p_now
    from claimed
    where delivery.id = claimed.id
    returning delivery.*
  )
  select
    leased.id,
    leased.user_id,
    leased.installation_id,
    installation.fcm_token,
    installation.platform,
    installation.time_zone,
    leased.kind,
    leased.local_date,
    leased.business_date,
    profile.current_streak,
    array(
      select expected.mission_key
      from unnest(array['daily_practice', 'daily_pvp']) as expected(mission_key)
      where not exists (
        select 1
        from public.daily_mission_progress progress
        where progress.user_id = leased.user_id
          and progress.business_date = leased.business_date
          and progress.mission_key = expected.mission_key
      )
      order by expected.mission_key
    ),
    leased.expires_at,
    leased.attempt_count
  from leased
  join public.push_installations installation
    on installation.user_id = leased.user_id
    and installation.installation_id = leased.installation_id
  join public.profiles profile on profile.id = leased.user_id;
end;
$$;

revoke all on function public.claim_due_notification_deliveries(timestamptz, integer)
  from public, anon, authenticated;
grant execute on function public.claim_due_notification_deliveries(timestamptz, integer)
  to service_role;
