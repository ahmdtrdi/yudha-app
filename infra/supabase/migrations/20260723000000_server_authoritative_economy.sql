-- =========================================================
-- Server-authoritative economy, loadout, and Hired Pass
-- =========================================================

alter table public.profiles
  add column if not exists equipped_tower_id text,
  add column if not exists hired_pass_expires_at timestamptz;

create table if not exists public.store_items (
  id text primary key,
  type text not null check (type in ('character_skin', 'arena', 'tower')),
  name text not null,
  description text not null default '',
  rarity text not null check (rarity in ('common', 'rare', 'epic', 'legendary')),
  coin_price integer not null default 0 check (coin_price >= 0),
  is_active boolean not null default true,
  is_pass_exclusive boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_inventory (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id text not null references public.store_items(id) on delete restrict,
  source text not null check (source in ('starter', 'purchase', 'hired_pass', 'admin')),
  source_ref text,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table if not exists public.store_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id text not null references public.store_items(id) on delete restrict,
  idempotency_key text not null,
  price_paid integer not null check (price_paid >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, item_id),
  unique (user_id, idempotency_key)
);

create table if not exists public.coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  delta integer not null check (delta <> 0),
  reason text not null check (
    reason in ('match_reward', 'store_purchase', 'hired_pass_reward', 'beta_credit', 'admin')
  ),
  reference_id text,
  idempotency_key text not null,
  balance_after integer not null check (balance_after >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create table if not exists public.hired_pass_seasons (
  id text primary key,
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.hired_pass_missions (
  id text primary key,
  season_id text not null references public.hired_pass_seasons(id) on delete cascade,
  title text not null,
  description text not null,
  event_type text not null check (
    event_type in ('practice_completed', 'battle_completed', 'interview_completed')
  ),
  cadence text not null check (cadence in ('daily', 'weekly', 'season')),
  target_count integer not null check (target_count > 0),
  points_reward integer not null check (points_reward > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.hired_pass_rewards (
  id text primary key,
  season_id text not null references public.hired_pass_seasons(id) on delete cascade,
  track text not null check (track in ('free', 'premium')),
  points_required integer not null check (points_required >= 0),
  label text not null,
  coins_reward integer not null default 0 check (coins_reward >= 0),
  item_id text references public.store_items(id) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (coins_reward > 0 or item_id is not null)
);

create table if not exists public.user_hired_pass_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  season_id text not null references public.hired_pass_seasons(id) on delete cascade,
  pass_points integer not null default 0 check (pass_points >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, season_id)
);

create table if not exists public.user_hired_pass_mission_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  mission_id text not null references public.hired_pass_missions(id) on delete cascade,
  period_start date not null,
  progress_count integer not null default 0 check (progress_count >= 0),
  completed_at timestamptz,
  points_awarded_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, mission_id, period_start)
);

create table if not exists public.hired_pass_activity_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mission_id text not null references public.hired_pass_missions(id) on delete cascade,
  source_type text not null,
  source_id text not null,
  period_start date not null,
  created_at timestamptz not null default now(),
  unique (user_id, mission_id, source_type, source_id)
);

create table if not exists public.user_hired_pass_reward_claims (
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_id text not null references public.hired_pass_rewards(id) on delete cascade,
  coins_awarded integer not null default 0 check (coins_awarded >= 0),
  item_id text references public.store_items(id) on delete restrict,
  claimed_at timestamptz not null default now(),
  primary key (user_id, reward_id)
);

insert into public.store_items
  (id, type, name, description, rarity, coin_price, is_pass_exclusive)
values
  ('character-basic-squire', 'character_skin', 'Squire', 'Ksatria pemula yang tangguh dan selalu siap berlatih.', 'common', 0, false),
  ('character-basic-pip', 'character_skin', 'Pip', 'Pemanah lincah dengan serangan alam yang presisi.', 'common', 500, false),
  ('character-rare-ignis', 'character_skin', 'Ignis', 'Penyihir api gesit dengan rentetan bara yang membara.', 'rare', 900, false),
  ('character-rare-brock', 'character_skin', 'Brock', 'Golem batu perkasa yang menghantam dengan tenaga magma.', 'rare', 1100, false),
  ('character-legend-drakor', 'character_skin', 'Drakor', 'Ksatria naga legendaris dengan kobaran api merah.', 'legendary', 2200, false),
  ('character-legend-luna', 'character_skin', 'Luna', 'Penyihir bintang legendaris dengan kekuatan galaksi.', 'legendary', 2500, false),
  ('tower-garda-biru', 'tower', 'Garda Biru', 'Benteng batu klasik dengan panji biru.', 'common', 0, false),
  ('tower-benteng-bara', 'tower', 'Benteng Bara', 'Menara coral hangat dengan ukiran emas.', 'rare', 650, false),
  ('arena-cpns', 'arena', 'Arena CPNS', 'Arena latihan CPNS.', 'common', 0, false),
  ('arena-bumn', 'arena', 'Arena BUMN', 'Arena latihan BUMN.', 'common', 0, false)
on conflict (id) do update set
  type = excluded.type,
  name = excluded.name,
  description = excluded.description,
  rarity = excluded.rarity,
  coin_price = excluded.coin_price,
  is_pass_exclusive = excluded.is_pass_exclusive,
  is_active = true,
  updated_at = now();

insert into public.hired_pass_seasons
  (id, name, starts_at, ends_at, is_active)
values
  ('2026-07', 'Hired Pass Juli 2026', '2026-07-01T00:00:00Z', '2026-08-01T00:00:00Z', true)
on conflict (id) do update set
  name = excluded.name,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.hired_pass_missions
  (id, season_id, title, description, event_type, cadence, target_count, points_reward)
values
  ('2026-07-practice-daily', '2026-07', 'Latihan harian', 'Selesaikan 3 sesi practice', 'practice_completed', 'daily', 3, 100),
  ('2026-07-battle-weekly', '2026-07', 'Pejuang mingguan', 'Mainkan 5 battle', 'battle_completed', 'weekly', 5, 250),
  ('2026-07-interview-season', '2026-07', 'Siap interview', 'Selesaikan 1 mock interview', 'interview_completed', 'season', 1, 200)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  event_type = excluded.event_type,
  cadence = excluded.cadence,
  target_count = excluded.target_count,
  points_reward = excluded.points_reward,
  is_active = true;

insert into public.hired_pass_rewards
  (id, season_id, track, points_required, label, coins_reward, item_id)
values
  ('free-100-coins', '2026-07', 'free', 100, '100 Y-Coin', 100, null),
  ('premium-100-coins', '2026-07', 'premium', 100, '250 Y-Coin', 250, null),
  ('free-300-coins', '2026-07', 'free', 300, '150 Y-Coin', 150, null),
  ('premium-300-tower', '2026-07', 'premium', 300, 'Benteng Bara', 0, 'tower-benteng-bara'),
  ('free-600-coins', '2026-07', 'free', 600, '300 Y-Coin', 300, null),
  ('premium-600-character', '2026-07', 'premium', 600, 'Pip', 0, 'character-basic-pip'),
  ('free-1000-coins', '2026-07', 'free', 1000, '500 Y-Coin', 500, null),
  ('premium-1000-coins', '2026-07', 'premium', 1000, '1.000 Y-Coin', 1000, null)
on conflict (id) do update set
  track = excluded.track,
  points_required = excluded.points_required,
  label = excluded.label,
  coins_reward = excluded.coins_reward,
  item_id = excluded.item_id,
  is_active = true;

-- Remove invalid historical loadout values before adding foreign keys.
update public.profiles
set equipped_avatar_id = null
where equipped_avatar_id is not null
  and not exists (
    select 1 from public.store_items
    where id = profiles.equipped_avatar_id and type = 'character_skin'
  );

update public.profiles
set equipped_arena_id = null
where equipped_arena_id is not null
  and not exists (
    select 1 from public.store_items
    where id = profiles.equipped_arena_id and type = 'arena'
  );

update public.profiles
set equipped_tower_id = null
where equipped_tower_id is not null
  and not exists (
    select 1 from public.store_items
    where id = profiles.equipped_tower_id and type = 'tower'
  );

insert into public.user_inventory (user_id, item_id, source, source_ref)
select profiles.id, store_items.id, 'starter', 'server-authoritative-economy-v1'
from public.profiles
cross join public.store_items
where store_items.coin_price = 0 and store_items.is_active
on conflict (user_id, item_id) do nothing;

insert into public.user_inventory (user_id, item_id, source, source_ref)
select profile.id, equipped.item_id, 'admin', 'profile-loadout-backfill'
from public.profiles profile
cross join lateral (
  values
    (profile.equipped_avatar_id),
    (profile.equipped_arena_id),
    (profile.equipped_tower_id)
) as equipped(item_id)
join public.store_items item on item.id = equipped.item_id
where equipped.item_id is not null
on conflict (user_id, item_id) do nothing;

update public.profiles set
  equipped_avatar_id = coalesce(equipped_avatar_id, 'character-basic-squire'),
  equipped_arena_id = coalesce(equipped_arena_id, 'arena-cpns'),
  equipped_tower_id = coalesce(equipped_tower_id, 'tower-garda-biru');

alter table public.profiles
  alter column equipped_avatar_id set default 'character-basic-squire',
  alter column equipped_arena_id set default 'arena-cpns',
  alter column equipped_tower_id set default 'tower-garda-biru';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_equipped_avatar_fk'
  ) then
    alter table public.profiles
      add constraint profiles_equipped_avatar_fk
      foreign key (equipped_avatar_id) references public.store_items(id);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_equipped_arena_fk'
  ) then
    alter table public.profiles
      add constraint profiles_equipped_arena_fk
      foreign key (equipped_arena_id) references public.store_items(id);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_equipped_tower_fk'
  ) then
    alter table public.profiles
      add constraint profiles_equipped_tower_fk
      foreign key (equipped_tower_id) references public.store_items(id);
  end if;
end
$$;

create index if not exists user_inventory_user_idx
  on public.user_inventory (user_id, acquired_at desc);
create index if not exists coin_transactions_user_idx
  on public.coin_transactions (user_id, created_at desc);
create index if not exists hired_pass_missions_season_event_idx
  on public.hired_pass_missions (season_id, event_type);
create index if not exists hired_pass_rewards_season_points_idx
  on public.hired_pass_rewards (season_id, points_required);

create or replace function public.record_hired_pass_activity(
  p_user_id uuid,
  p_event_type text,
  p_source_id text,
  p_occurred_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mission public.hired_pass_missions%rowtype;
  v_period_start date;
  v_event_id uuid;
  v_progress_count integer;
  v_awarded_at timestamptz;
  v_points_awarded integer := 0;
  v_season_id text;
  v_total_points integer := 0;
begin
  if p_event_type not in ('practice_completed', 'battle_completed', 'interview_completed') then
    raise exception 'Unsupported Hired Pass event type.';
  end if;
  if nullif(btrim(p_source_id), '') is null then
    raise exception 'Hired Pass source ID is required.';
  end if;

  for v_mission in
    select mission.*
    from public.hired_pass_missions mission
    join public.hired_pass_seasons season on season.id = mission.season_id
    where mission.event_type = p_event_type
      and mission.is_active
      and season.is_active
      and p_occurred_at >= season.starts_at
      and p_occurred_at < season.ends_at
  loop
    v_season_id := v_mission.season_id;
    v_event_id := null;
    v_period_start := case v_mission.cadence
      when 'daily' then (p_occurred_at at time zone 'UTC')::date
      when 'weekly' then date_trunc('week', p_occurred_at at time zone 'UTC')::date
      else (
        select (starts_at at time zone 'UTC')::date
        from public.hired_pass_seasons
        where id = v_mission.season_id
      )
    end;

    insert into public.hired_pass_activity_events
      (user_id, mission_id, source_type, source_id, period_start)
    values
      (p_user_id, v_mission.id, p_event_type, p_source_id, v_period_start)
    on conflict (user_id, mission_id, source_type, source_id) do nothing
    returning id into v_event_id;

    if v_event_id is null then
      continue;
    end if;

    insert into public.user_hired_pass_progress (user_id, season_id)
    values (p_user_id, v_mission.season_id)
    on conflict (user_id, season_id) do nothing;

    insert into public.user_hired_pass_mission_progress
      (user_id, mission_id, period_start, progress_count, updated_at)
    values
      (p_user_id, v_mission.id, v_period_start, 1, now())
    on conflict (user_id, mission_id, period_start) do update set
      progress_count = least(
        v_mission.target_count,
        public.user_hired_pass_mission_progress.progress_count + 1
      ),
      updated_at = now()
    returning progress_count, points_awarded_at
      into v_progress_count, v_awarded_at;

    if v_progress_count >= v_mission.target_count and v_awarded_at is null then
      update public.user_hired_pass_mission_progress
      set
        completed_at = coalesce(completed_at, now()),
        points_awarded_at = now(),
        updated_at = now()
      where user_id = p_user_id
        and mission_id = v_mission.id
        and period_start = v_period_start
        and points_awarded_at is null
      returning points_awarded_at into v_awarded_at;

      if found then
        update public.user_hired_pass_progress
        set
          pass_points = pass_points + v_mission.points_reward,
          updated_at = now()
        where user_id = p_user_id and season_id = v_mission.season_id;
        v_points_awarded := v_points_awarded + v_mission.points_reward;
      end if;
    end if;
  end loop;

  if v_season_id is not null then
    select pass_points into v_total_points
    from public.user_hired_pass_progress
    where user_id = p_user_id and season_id = v_season_id;
  end if;

  return jsonb_build_object(
    'seasonId', v_season_id,
    'pointsAwarded', v_points_awarded,
    'passPoints', coalesce(v_total_points, 0)
  );
end;
$$;

create or replace function public.purchase_store_item(
  p_user_id uuid,
  p_item_id text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.store_items%rowtype;
  v_existing public.store_purchases%rowtype;
  v_purchase_id uuid;
  v_balance integer;
begin
  if nullif(btrim(p_idempotency_key), '') is null then
    raise exception 'Idempotency key is required.';
  end if;

  select * into v_existing
  from public.store_purchases
  where user_id = p_user_id and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.item_id <> p_item_id then
      raise exception 'Idempotency key was already used for another item.';
    end if;
    select coins into v_balance from public.profiles where id = p_user_id;
    return jsonb_build_object(
      'purchased', false,
      'replayed', true,
      'purchaseId', v_existing.id,
      'itemId', v_existing.item_id,
      'coins', v_balance
    );
  end if;

  select * into v_item
  from public.store_items
  where id = p_item_id and is_active
  for update;

  if not found then
    raise exception 'Store item is not available.';
  end if;
  if v_item.is_pass_exclusive then
    raise exception 'Store item is only available from Hired Pass.';
  end if;
  if exists (
    select 1 from public.user_inventory
    where user_id = p_user_id and item_id = p_item_id
  ) then
    raise exception 'Store item is already owned.';
  end if;

  select coins into v_balance
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;
  if v_balance < v_item.coin_price then
    raise exception 'Insufficient Y-Coin balance.';
  end if;

  update public.profiles
  set coins = coins - v_item.coin_price
  where id = p_user_id
  returning coins into v_balance;

  insert into public.store_purchases
    (user_id, item_id, idempotency_key, price_paid)
  values
    (p_user_id, p_item_id, p_idempotency_key, v_item.coin_price)
  returning id into v_purchase_id;

  insert into public.user_inventory (user_id, item_id, source, source_ref)
  values (p_user_id, p_item_id, 'purchase', v_purchase_id::text);

  if v_item.coin_price > 0 then
    insert into public.coin_transactions
      (user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values
      (
        p_user_id,
        -v_item.coin_price,
        'store_purchase',
        v_purchase_id::text,
        'store-purchase:' || p_idempotency_key,
        v_balance
      );
  end if;

  return jsonb_build_object(
    'purchased', true,
    'replayed', false,
    'purchaseId', v_purchase_id,
    'itemId', p_item_id,
    'coins', v_balance
  );
end;
$$;

create or replace function public.set_profile_loadout(
  p_user_id uuid,
  p_avatar_id text default null,
  p_tower_id text default null,
  p_arena_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_avatar_id is null and p_tower_id is null and p_arena_id is null then
    raise exception 'At least one loadout field is required.';
  end if;

  if p_avatar_id is not null and not exists (
    select 1
    from public.user_inventory inventory
    join public.store_items item on item.id = inventory.item_id
    where inventory.user_id = p_user_id
      and item.id = p_avatar_id
      and item.type = 'character_skin'
      and item.is_active
  ) then
    raise exception 'Character is not owned or available.';
  end if;

  if p_tower_id is not null and not exists (
    select 1
    from public.user_inventory inventory
    join public.store_items item on item.id = inventory.item_id
    where inventory.user_id = p_user_id
      and item.id = p_tower_id
      and item.type = 'tower'
      and item.is_active
  ) then
    raise exception 'Tower is not owned or available.';
  end if;

  if p_arena_id is not null and not exists (
    select 1
    from public.user_inventory inventory
    join public.store_items item on item.id = inventory.item_id
    where inventory.user_id = p_user_id
      and item.id = p_arena_id
      and item.type = 'arena'
      and item.is_active
  ) then
    raise exception 'Arena is not owned or available.';
  end if;

  update public.profiles set
    equipped_avatar_id = coalesce(p_avatar_id, equipped_avatar_id),
    equipped_tower_id = coalesce(p_tower_id, equipped_tower_id),
    equipped_arena_id = coalesce(p_arena_id, equipped_arena_id)
  where id = p_user_id;

  if not found then
    raise exception 'Profile not found.';
  end if;

  return (
    select jsonb_build_object(
      'characterId', equipped_avatar_id,
      'towerId', equipped_tower_id,
      'arenaId', equipped_arena_id
    )
    from public.profiles
    where id = p_user_id
  );
end;
$$;

create or replace function public.grant_beta_credit(
  p_user_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance integer;
  v_existing public.coin_transactions%rowtype;
begin
  if nullif(btrim(p_idempotency_key), '') is null then
    raise exception 'Idempotency key is required.';
  end if;

  select * into v_existing
  from public.coin_transactions
  where user_id = p_user_id
    and idempotency_key = 'beta-credit:' || p_idempotency_key;

  if found then
    return jsonb_build_object(
      'credited', false,
      'replayed', true,
      'coins', v_existing.balance_after
    );
  end if;

  update public.profiles
  set coins = coins + 100
  where id = p_user_id
  returning coins into v_balance;

  if not found then
    raise exception 'Profile not found.';
  end if;

  insert into public.coin_transactions
    (user_id, delta, reason, reference_id, idempotency_key, balance_after)
  values
    (
      p_user_id,
      100,
      'beta_credit',
      p_idempotency_key,
      'beta-credit:' || p_idempotency_key,
      v_balance
    );

  return jsonb_build_object(
    'credited', true,
    'replayed', false,
    'coins', v_balance
  );
end;
$$;

create or replace function public.claim_hired_pass_reward(
  p_user_id uuid,
  p_reward_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reward public.hired_pass_rewards%rowtype;
  v_points integer := 0;
  v_expires_at timestamptz;
  v_balance integer;
begin
  select reward.* into v_reward
  from public.hired_pass_rewards reward
  join public.hired_pass_seasons season on season.id = reward.season_id
  where reward.id = p_reward_id
    and reward.is_active
    and season.is_active
    and now() >= season.starts_at
    and now() < season.ends_at;

  if not found then
    raise exception 'Hired Pass reward is not available.';
  end if;

  select
    coalesce(progress.pass_points, 0),
    profile.hired_pass_expires_at,
    profile.coins
  into v_points, v_expires_at, v_balance
  from public.profiles profile
  left join public.user_hired_pass_progress progress
    on progress.user_id = profile.id
    and progress.season_id = v_reward.season_id
  where profile.id = p_user_id
  for update of profile;

  if not found then
    raise exception 'Profile not found.';
  end if;
  if v_points < v_reward.points_required then
    raise exception 'Not enough Hired Pass points.';
  end if;
  if v_reward.track = 'premium'
    and (v_expires_at is null or v_expires_at <= now()) then
    raise exception 'An active Hired Pass entitlement is required.';
  end if;

  insert into public.user_hired_pass_reward_claims
    (user_id, reward_id, coins_awarded, item_id)
  values
    (p_user_id, v_reward.id, v_reward.coins_reward, v_reward.item_id)
  on conflict (user_id, reward_id) do nothing;

  if not found then
    return jsonb_build_object(
      'claimed', false,
      'reason', 'already_claimed',
      'rewardId', v_reward.id,
      'coins', v_balance
    );
  end if;

  if v_reward.coins_reward > 0 then
    update public.profiles
    set coins = coins + v_reward.coins_reward
    where id = p_user_id
    returning coins into v_balance;

    insert into public.coin_transactions
      (user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values
      (
        p_user_id,
        v_reward.coins_reward,
        'hired_pass_reward',
        v_reward.id,
        'hired-pass-reward:' || v_reward.id,
        v_balance
      );
  end if;

  if v_reward.item_id is not null then
    insert into public.user_inventory (user_id, item_id, source, source_ref)
    values (p_user_id, v_reward.item_id, 'hired_pass', v_reward.id)
    on conflict (user_id, item_id) do nothing;
  end if;

  return jsonb_build_object(
    'claimed', true,
    'rewardId', v_reward.id,
    'coins', v_balance,
    'itemId', v_reward.item_id
  );
end;
$$;

create or replace function public.finalize_match_result(
  p_room_id text,
  p_mode text,
  p_player_a_id uuid,
  p_player_b_id uuid,
  p_winner_user_id uuid,
  p_loser_user_id uuid,
  p_outcome text,
  p_reason text,
  p_player_a_hp int,
  p_player_b_hp int,
  p_player_a_points int,
  p_player_b_points int,
  p_duration_seconds int default null,
  p_started_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.match_results%rowtype;
  v_is_bot boolean;
  v_rating_delta_a int := 0;
  v_rating_delta_b int := 0;
  v_coins_delta_a int := 0;
  v_coins_delta_b int := 0;
  v_balance_a int;
  v_balance_b int;
  v_rating_win constant int := 20;
  v_rating_lose constant int := -12;
  v_coins_win constant int := 10;
  v_coins_lose constant int := 3;
  v_coins_draw constant int := 5;
begin
  if p_mode not in ('player', 'bot') then
    raise exception 'Unsupported match mode.';
  end if;
  if p_outcome not in ('player_a_win', 'player_b_win', 'draw') then
    raise exception 'Unsupported match outcome.';
  end if;

  v_is_bot := (p_mode = 'bot');

  if not v_is_bot then
    if p_outcome = 'player_a_win' then
      v_rating_delta_a := v_rating_win;
      v_rating_delta_b := v_rating_lose;
    elsif p_outcome = 'player_b_win' then
      v_rating_delta_a := v_rating_lose;
      v_rating_delta_b := v_rating_win;
    end if;
  end if;

  if p_outcome = 'player_a_win' then
    v_coins_delta_a := v_coins_win;
    v_coins_delta_b := v_coins_lose;
  elsif p_outcome = 'player_b_win' then
    v_coins_delta_a := v_coins_lose;
    v_coins_delta_b := v_coins_win;
  else
    v_coins_delta_a := v_coins_draw;
    v_coins_delta_b := v_coins_draw;
  end if;

  if v_is_bot then
    v_rating_delta_b := 0;
    v_coins_delta_b := 0;
  end if;

  insert into public.match_results (
    room_id,
    mode,
    player_a_id,
    player_b_id,
    winner_user_id,
    loser_user_id,
    outcome,
    reason,
    player_a_hp,
    player_b_hp,
    player_a_points,
    player_b_points,
    rating_delta_a,
    rating_delta_b,
    coins_delta_a,
    coins_delta_b,
    duration_seconds,
    started_at,
    ended_at
  )
  values (
    p_room_id,
    p_mode,
    p_player_a_id,
    p_player_b_id,
    p_winner_user_id,
    p_loser_user_id,
    p_outcome,
    p_reason,
    p_player_a_hp,
    p_player_b_hp,
    p_player_a_points,
    p_player_b_points,
    v_rating_delta_a,
    v_rating_delta_b,
    v_coins_delta_a,
    v_coins_delta_b,
    p_duration_seconds,
    p_started_at,
    now()
  )
  on conflict (room_id) do nothing
  returning * into v_result;

  if v_result.id is null then
    select * into v_result
    from public.match_results
    where room_id = p_room_id;

    return jsonb_build_object(
      'persisted', false,
      'reason', 'duplicate',
      'matchResultId', v_result.id,
      'ratingDeltaA', v_result.rating_delta_a,
      'ratingDeltaB', v_result.rating_delta_b,
      'coinsDeltaA', v_result.coins_delta_a,
      'coinsDeltaB', v_result.coins_delta_b
    );
  end if;

  update public.profiles set
    rank_points = greatest(0, rank_points + v_rating_delta_a),
    total_matches = total_matches + 1,
    wins = wins + (case when p_winner_user_id = p_player_a_id then 1 else 0 end),
    losses = losses + (case when p_loser_user_id = p_player_a_id then 1 else 0 end),
    winrate = round(
      (
        wins + (case when p_winner_user_id = p_player_a_id then 1 else 0 end)
      )::numeric / (total_matches + 1) * 100,
      2
    ),
    coins = coins + v_coins_delta_a
  where id = p_player_a_id
  returning coins into v_balance_a;

  if not found then
    raise exception 'Player A profile not found.';
  end if;

  insert into public.coin_transactions
    (user_id, delta, reason, reference_id, idempotency_key, balance_after)
  values
    (
      p_player_a_id,
      v_coins_delta_a,
      'match_reward',
      p_room_id,
      'match:' || p_room_id || ':player-a',
      v_balance_a
    );

  perform public.record_hired_pass_activity(
    p_player_a_id,
    'battle_completed',
    p_room_id,
    now()
  );

  if not v_is_bot and p_player_b_id is not null then
    update public.profiles set
      rank_points = greatest(0, rank_points + v_rating_delta_b),
      total_matches = total_matches + 1,
      wins = wins + (case when p_winner_user_id = p_player_b_id then 1 else 0 end),
      losses = losses + (case when p_loser_user_id = p_player_b_id then 1 else 0 end),
      winrate = round(
        (
          wins + (case when p_winner_user_id = p_player_b_id then 1 else 0 end)
        )::numeric / (total_matches + 1) * 100,
        2
      ),
      coins = coins + v_coins_delta_b
    where id = p_player_b_id
    returning coins into v_balance_b;

    if not found then
      raise exception 'Player B profile not found.';
    end if;

    insert into public.coin_transactions
      (user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values
      (
        p_player_b_id,
        v_coins_delta_b,
        'match_reward',
        p_room_id,
        'match:' || p_room_id || ':player-b',
        v_balance_b
      );

    perform public.record_hired_pass_activity(
      p_player_b_id,
      'battle_completed',
      p_room_id,
      now()
    );
  end if;

  return jsonb_build_object(
    'persisted', true,
    'matchResultId', v_result.id,
    'ratingDeltaA', v_rating_delta_a,
    'ratingDeltaB', v_rating_delta_b,
    'coinsDeltaA', v_coins_delta_a,
    'coinsDeltaB', v_coins_delta_b
  );
end;
$$;

create or replace function public.record_practice_hired_pass_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.record_hired_pass_activity(
    new.user_id,
    'practice_completed',
    new.id::text,
    new.finished_at
  );
  return new;
end;
$$;

drop trigger if exists practice_hired_pass_completion
  on public.practice_sessions;
create trigger practice_hired_pass_completion
after update of finished_at on public.practice_sessions
for each row
when (old.finished_at is null and new.finished_at is not null)
execute function public.record_practice_hired_pass_completion();

create or replace function public.record_interview_hired_pass_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.record_hired_pass_activity(
    new.user_id,
    'interview_completed',
    new.id::text,
    new.updated_at
  );
  return new;
end;
$$;

drop trigger if exists interview_hired_pass_completion
  on public.interview_sessions;
create trigger interview_hired_pass_completion
after update of status on public.interview_sessions
for each row
when (old.status is distinct from 'completed' and new.status = 'completed')
execute function public.record_interview_hired_pass_completion();

-- Keep signup defaults and starter inventory server-owned.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    username,
    full_name,
    target,
    equipped_avatar_id,
    equipped_arena_id,
    equipped_tower_id
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'username',
      split_part(new.email, '@', 1),
      'player'
    ),
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'display_name'), '')
    ),
    new.raw_user_meta_data ->> 'target',
    'character-basic-squire',
    'arena-cpns',
    'tower-garda-biru'
  )
  on conflict (id) do nothing;

  insert into public.user_inventory (user_id, item_id, source, source_ref)
  select new.id, item.id, 'starter', 'signup'
  from public.store_items item
  where item.coin_price = 0 and item.is_active
  on conflict (user_id, item_id) do nothing;

  return new;
end;
$$;

alter table public.store_items enable row level security;
alter table public.user_inventory enable row level security;
alter table public.store_purchases enable row level security;
alter table public.coin_transactions enable row level security;
alter table public.hired_pass_seasons enable row level security;
alter table public.hired_pass_missions enable row level security;
alter table public.hired_pass_rewards enable row level security;
alter table public.user_hired_pass_progress enable row level security;
alter table public.user_hired_pass_mission_progress enable row level security;
alter table public.hired_pass_activity_events enable row level security;
alter table public.user_hired_pass_reward_claims enable row level security;

drop policy if exists "Store items are publicly readable" on public.store_items;
create policy "Store items are publicly readable"
  on public.store_items for select to anon, authenticated using (is_active);

drop policy if exists "Users can read their own inventory" on public.user_inventory;
create policy "Users can read their own inventory"
  on public.user_inventory for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can read their own purchases" on public.store_purchases;
create policy "Users can read their own purchases"
  on public.store_purchases for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can read their own coin transactions" on public.coin_transactions;
create policy "Users can read their own coin transactions"
  on public.coin_transactions for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Hired Pass seasons are publicly readable" on public.hired_pass_seasons;
create policy "Hired Pass seasons are publicly readable"
  on public.hired_pass_seasons for select to anon, authenticated using (is_active);

drop policy if exists "Hired Pass missions are publicly readable" on public.hired_pass_missions;
create policy "Hired Pass missions are publicly readable"
  on public.hired_pass_missions for select to anon, authenticated using (is_active);

drop policy if exists "Hired Pass rewards are publicly readable" on public.hired_pass_rewards;
create policy "Hired Pass rewards are publicly readable"
  on public.hired_pass_rewards for select to anon, authenticated using (is_active);

drop policy if exists "Users can read their own Hired Pass progress" on public.user_hired_pass_progress;
create policy "Users can read their own Hired Pass progress"
  on public.user_hired_pass_progress for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can read their own mission progress" on public.user_hired_pass_mission_progress;
create policy "Users can read their own mission progress"
  on public.user_hired_pass_mission_progress for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can read their own reward claims" on public.user_hired_pass_reward_claims;
create policy "Users can read their own reward claims"
  on public.user_hired_pass_reward_claims for select to authenticated using (auth.uid() = user_id);

-- Profile and economy mutations must go through trusted backend services.
drop policy if exists "Users can update their own profile" on public.profiles;
revoke update on public.profiles from anon, authenticated;
revoke insert, update, delete on public.user_inventory from anon, authenticated;
revoke insert, update, delete on public.store_purchases from anon, authenticated;
revoke insert, update, delete on public.coin_transactions from anon, authenticated;
revoke insert, update, delete on public.user_hired_pass_progress from anon, authenticated;
revoke insert, update, delete on public.user_hired_pass_mission_progress from anon, authenticated;
revoke insert, update, delete on public.hired_pass_activity_events from anon, authenticated;
revoke insert, update, delete on public.user_hired_pass_reward_claims from anon, authenticated;

revoke all on function public.record_hired_pass_activity(uuid, text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.purchase_store_item(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.set_profile_loadout(uuid, text, text, text)
  from public, anon, authenticated;
revoke all on function public.grant_beta_credit(uuid, text)
  from public, anon, authenticated;
revoke all on function public.claim_hired_pass_reward(uuid, text)
  from public, anon, authenticated;
revoke all on function public.finalize_match_result(
  text, text, uuid, uuid, uuid, uuid, text, text,
  int, int, int, int, int, timestamptz
) from public, anon, authenticated;

grant execute on function public.record_hired_pass_activity(uuid, text, text, timestamptz)
  to service_role;
grant execute on function public.purchase_store_item(uuid, text, text)
  to service_role;
grant execute on function public.set_profile_loadout(uuid, text, text, text)
  to service_role;
grant execute on function public.grant_beta_credit(uuid, text)
  to service_role;
grant execute on function public.claim_hired_pass_reward(uuid, text)
  to service_role;
grant execute on function public.finalize_match_result(
  text, text, uuid, uuid, uuid, uuid, text, text,
  int, int, int, int, int, timestamptz
) to service_role;
