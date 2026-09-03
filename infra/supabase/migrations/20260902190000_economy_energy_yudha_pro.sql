begin;

-- All values are provisional balancing data. Runtime functions read this row so
-- tuning does not require rewriting transaction logic.
create table if not exists public.economy_policy_versions (
  id text primary key,
  policy jsonb not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(policy) = 'object')
);
create unique index if not exists economy_policy_one_active_idx
  on public.economy_policy_versions(is_active) where is_active;

insert into public.economy_policy_versions(id, policy, is_active)
values (
  'economy-v1',
  '{
    "version":"economy-v1","timezone":"Asia/Jakarta","balancingStatus":"provisional",
    "energy":{"freeCap":10,"dailyRefillTo":10,"entryCost":2,"completionReward":1,"adReward":2,"adDailyLimit":3,"packs":[{"id":"energy-5","energy":5,"yCoinCost":50}]},
    "yCoin":{"adReward":5,"adDailyLimit":3,"hintCost":5,"interviewCost":100,"proMonthlyGrant":500,"casualCompletionReward":3,"paidPackages":[
      {"id":"pack-500","coins":500,"priceLabel":"Rp9.000","enabled":false},
      {"id":"pack-1200","coins":1200,"priceLabel":"Rp19.000","enabled":false},
      {"id":"pack-2800","coins":2800,"priceLabel":"Rp39.000","enabled":false},
      {"id":"pack-6800","coins":6800,"priceLabel":"Rp89.000","enabled":false}
    ]},
    "pro":{"planId":"pro-monthly","durationDays":30,"checkoutEnabled":false,"exclusiveSkinIds":["character-basic-pip","character-rare-brock"]}
  }'::jsonb,
  true
)
on conflict (id) do update set policy = excluded.policy, is_active = excluded.is_active;

alter table public.profiles
  add column if not exists energy_balance integer not null default 10,
  add column if not exists energy_refilled_on date not null default public.wib_business_date(clock_timestamp());
alter table public.profiles drop constraint if exists profiles_energy_balance_check;
alter table public.profiles add constraint profiles_energy_balance_check check (energy_balance >= 0);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'store_items'
      and column_name = 'is_pass_exclusive'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'store_items'
      and column_name = 'is_pro_exclusive'
  ) then
    alter table public.store_items rename column is_pass_exclusive to is_pro_exclusive;
  end if;
end $$;

update public.store_items set is_pro_exclusive = id in (
  'character-basic-pip', 'character-rare-brock'
);

alter table public.user_inventory drop constraint if exists user_inventory_source_check;
alter table public.user_inventory add constraint user_inventory_source_check check (
  source in ('starter', 'purchase', 'hired_pass', 'pro', 'admin')
);

alter table public.coin_transactions drop constraint if exists coin_transactions_reason_check;
alter table public.coin_transactions add constraint coin_transactions_reason_check check (
  reason in (
    'match_reward', 'solo_reward', 'store_purchase', 'hired_pass_reward',
    'beta_credit', 'daily_mission', 'admin', 'energy_purchase',
    'interview_session', 'pro_monthly_grant', 'ad_reward'
  )
);

create table if not exists public.energy_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  delta integer not null check (delta <> 0),
  reason text not null check (reason in (
    'daily_refill', 'entry_reserve', 'entry_release', 'completion_reward',
    'ad_reward', 'ycoin_purchase', 'admin'
  )),
  reference_id text,
  idempotency_key text not null,
  balance_after integer not null check (balance_after >= 0),
  business_date date not null default public.wib_business_date(clock_timestamp()),
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create table if not exists public.energy_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mode text not null check (mode in ('solo', 'practice', 'bot', 'casual', 'ranked', 'private')),
  reference_id text not null,
  idempotency_key text not null,
  amount integer not null check (amount >= 0),
  status text not null check (status in ('reserved', 'committed', 'released', 'expired')),
  reserve_transaction_id uuid references public.energy_transactions(id),
  release_transaction_id uuid references public.energy_transactions(id),
  expires_at timestamptz,
  committed_at timestamptz,
  released_at timestamptz,
  release_reason text,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
create index if not exists energy_reservations_pending_idx
  on public.energy_reservations(user_id, mode, created_at desc) where status = 'reserved';

create table if not exists public.pro_entitlement_periods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_id text not null,
  source text not null check (source in ('beta', 'payment', 'admin')),
  status text not null default 'active' check (status in ('active', 'expired', 'revoked')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  selected_skin_id text references public.store_items(id) on delete restrict,
  coin_transaction_id uuid references public.coin_transactions(id),
  idempotency_key text not null,
  request_hash text not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique (user_id, idempotency_key)
);
create index if not exists pro_entitlement_active_user_idx
  on public.pro_entitlement_periods(user_id, ends_at desc) where status = 'active';

create table if not exists public.ad_reward_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_type text not null check (reward_type in ('energy', 'y_coin')),
  placement_id text not null,
  provider text not null,
  provider_transaction_id text not null,
  idempotency_key text not null,
  business_date date not null,
  amount_awarded integer not null check (amount_awarded >= 0),
  energy_transaction_id uuid references public.energy_transactions(id),
  coin_transaction_id uuid references public.coin_transactions(id),
  created_at timestamptz not null default now(),
  unique (provider, provider_transaction_id),
  unique (user_id, idempotency_key)
);

create table if not exists public.interview_session_charges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null unique references public.interview_sessions(id) on delete cascade,
  amount integer not null check (amount > 0),
  idempotency_key text not null,
  request_hash text not null,
  coin_transaction_id uuid not null unique references public.coin_transactions(id),
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

alter table public.economy_policy_versions enable row level security;
alter table public.energy_transactions enable row level security;
alter table public.energy_reservations enable row level security;
alter table public.pro_entitlement_periods enable row level security;
alter table public.ad_reward_claims enable row level security;
alter table public.interview_session_charges enable row level security;

revoke all on public.economy_policy_versions, public.energy_transactions,
  public.energy_reservations, public.pro_entitlement_periods,
  public.ad_reward_claims, public.interview_session_charges
  from public, anon, authenticated;
grant select on public.energy_transactions, public.energy_reservations,
  public.pro_entitlement_periods, public.ad_reward_claims,
  public.interview_session_charges to authenticated;
grant all on public.economy_policy_versions, public.energy_transactions,
  public.energy_reservations, public.pro_entitlement_periods,
  public.ad_reward_claims, public.interview_session_charges to service_role;

drop policy if exists "Users can read own energy transactions" on public.energy_transactions;
create policy "Users can read own energy transactions" on public.energy_transactions
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can read own energy reservations" on public.energy_reservations;
create policy "Users can read own energy reservations" on public.energy_reservations
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can read own Pro periods" on public.pro_entitlement_periods;
create policy "Users can read own Pro periods" on public.pro_entitlement_periods
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can read own ad claims" on public.ad_reward_claims;
create policy "Users can read own ad claims" on public.ad_reward_claims
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can read own interview charges" on public.interview_session_charges;
create policy "Users can read own interview charges" on public.interview_session_charges
  for select to authenticated using (auth.uid() = user_id);

create or replace function public.active_economy_policy()
returns jsonb language sql stable security definer set search_path = public as $$
  select policy from public.economy_policy_versions where is_active limit 1
$$;

create or replace function public.has_active_pro(p_user_id uuid, p_at timestamptz default clock_timestamp())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.pro_entitlement_periods
    where user_id = p_user_id and status = 'active'
      and starts_at <= p_at and ends_at > p_at
  )
$$;

create or replace function public.apply_daily_energy_refill(
  p_user_id uuid,
  p_at timestamptz default clock_timestamp()
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_policy jsonb := public.active_economy_policy();
  v_date date := public.wib_business_date(p_at);
  v_refill integer := (v_policy #>> '{energy,dailyRefillTo}')::integer;
  v_before integer;
  v_after integer;
  v_last date;
begin
  select energy_balance, energy_refilled_on into v_before, v_last
  from public.profiles where id = p_user_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile'; end if;
  v_after := v_before;
  if v_last < v_date then
    v_after := greatest(v_before, v_refill);
    update public.profiles set energy_balance = v_after, energy_refilled_on = v_date,
      updated_at = p_at where id = p_user_id;
    if v_after <> v_before then
      insert into public.energy_transactions(
        user_id, delta, reason, reference_id, idempotency_key, balance_after, business_date, created_at
      ) values (
        p_user_id, v_after - v_before, 'daily_refill', v_date::text,
        'daily-refill:' || v_date::text, v_after, v_date, p_at
      ) on conflict (user_id, idempotency_key) do nothing;
    end if;
  end if;
  return jsonb_build_object('balance', v_after, 'businessDate', v_date, 'refilled', v_after <> v_before);
end;
$$;

create or replace function public.get_economy_state(
  p_user_id uuid,
  p_at timestamptz default clock_timestamp()
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_policy jsonb := public.active_economy_policy();
  v_refill jsonb;
  v_coins integer;
  v_energy integer;
  v_date date := public.wib_business_date(p_at);
  v_pro public.pro_entitlement_periods%rowtype;
  v_energy_ads integer;
  v_coin_ads integer;
begin
  v_refill := public.apply_daily_energy_refill(p_user_id, p_at);
  select coins, energy_balance into v_coins, v_energy from public.profiles where id = p_user_id;
  select * into v_pro from public.pro_entitlement_periods
    where user_id = p_user_id and status = 'active' and starts_at <= p_at and ends_at > p_at
    order by ends_at desc limit 1;
  select count(*) filter (where reward_type = 'energy'), count(*) filter (where reward_type = 'y_coin')
    into v_energy_ads, v_coin_ads
  from public.ad_reward_claims where user_id = p_user_id and business_date = v_date;
  return jsonb_build_object(
    'policyVersion', v_policy ->> 'version', 'businessDate', v_date,
    'yCoins', v_coins,
    'energy', jsonb_build_object(
      'balance', v_energy,
      'cap', (v_policy #>> '{energy,freeCap}')::integer,
      'unlimited', v_pro.id is not null,
      'nextRefillAt', ((v_date + 1)::timestamp at time zone 'Asia/Jakarta')
    ),
    'pro', jsonb_build_object(
      'active', v_pro.id is not null,
      'planId', v_pro.plan_id,
      'startsAt', v_pro.starts_at,
      'expiresAt', v_pro.ends_at,
      'selectedSkinId', v_pro.selected_skin_id
    ),
    'adRewards', jsonb_build_object(
      'enabled', false,
      'energy', jsonb_build_object('amount', (v_policy #>> '{energy,adReward}')::integer, 'claimedToday', v_energy_ads, 'dailyLimit', (v_policy #>> '{energy,adDailyLimit}')::integer),
      'yCoin', jsonb_build_object('amount', (v_policy #>> '{yCoin,adReward}')::integer, 'claimedToday', v_coin_ads, 'dailyLimit', (v_policy #>> '{yCoin,adDailyLimit}')::integer)
    )
  );
end;
$$;

create or replace function public.reserve_energy(
  p_user_id uuid,
  p_mode text,
  p_reference_id text,
  p_idempotency_key text,
  p_ttl_seconds integer default 900,
  p_commit_immediately boolean default false
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_policy jsonb := public.active_economy_policy();
  v_existing public.energy_reservations%rowtype;
  v_amount integer := (v_policy #>> '{energy,entryCost}')::integer;
  v_balance integer;
  v_reservation_id uuid;
  v_transaction_id uuid;
  v_unlimited boolean;
begin
  if p_mode not in ('solo','practice','bot','casual','ranked','private') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported energy mode';
  end if;
  if nullif(btrim(p_idempotency_key), '') is null or char_length(p_idempotency_key) > 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  perform public.apply_daily_energy_refill(p_user_id);
  select * into v_existing from public.energy_reservations
    where user_id = p_user_id and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.mode <> p_mode or v_existing.reference_id <> p_reference_id then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    select energy_balance into v_balance from public.profiles where id = p_user_id;
    return jsonb_build_object('reservationId', v_existing.id, 'status', v_existing.status,
      'energyCost', v_existing.amount, 'energyBalance', v_balance, 'unlimited', v_existing.amount = 0, 'replayed', true);
  end if;
  select energy_balance into v_balance from public.profiles where id = p_user_id for update;
  v_unlimited := public.has_active_pro(p_user_id);
  if v_unlimited then v_amount := 0; end if;
  if v_balance < v_amount then
    raise exception using errcode = 'P0001', message = 'INSUFFICIENT_ENERGY';
  end if;
  v_reservation_id := gen_random_uuid();
  if v_amount > 0 then
    update public.profiles set energy_balance = energy_balance - v_amount, updated_at = clock_timestamp()
      where id = p_user_id returning energy_balance into v_balance;
    insert into public.energy_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
      values (p_user_id, -v_amount, 'entry_reserve', p_reference_id, 'reserve:' || p_idempotency_key, v_balance)
      returning id into v_transaction_id;
  end if;
  insert into public.energy_reservations(
    id, user_id, mode, reference_id, idempotency_key, amount, status,
    reserve_transaction_id, expires_at, committed_at
  ) values (
    v_reservation_id, p_user_id, p_mode, p_reference_id, p_idempotency_key, v_amount,
    case when p_commit_immediately then 'committed' else 'reserved' end,
    v_transaction_id,
    case when p_commit_immediately then null else clock_timestamp() + make_interval(secs => greatest(30, p_ttl_seconds)) end,
    case when p_commit_immediately then clock_timestamp() else null end
  );
  return jsonb_build_object('reservationId', v_reservation_id,
    'status', case when p_commit_immediately then 'committed' else 'reserved' end,
    'energyCost', v_amount, 'energyBalance', v_balance, 'unlimited', v_unlimited, 'replayed', false);
end;
$$;

create or replace function public.commit_energy_reservation(
  p_user_id uuid, p_mode text, p_reference_id text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_row public.energy_reservations%rowtype; v_balance integer;
begin
  select * into v_row from public.energy_reservations
    where user_id = p_user_id and mode = p_mode and status = 'reserved'
      and (p_reference_id is null or reference_id = p_reference_id)
    order by created_at desc limit 1 for update;
  if not found then
    select energy_balance into v_balance from public.profiles where id = p_user_id;
    return jsonb_build_object('committed', false, 'reason', 'not_reserved', 'energyBalance', v_balance);
  end if;
  update public.energy_reservations set status = 'committed', committed_at = clock_timestamp(), expires_at = null
    where id = v_row.id;
  select energy_balance into v_balance from public.profiles where id = p_user_id;
  return jsonb_build_object('committed', true, 'reservationId', v_row.id, 'energyBalance', v_balance, 'energyCost', v_row.amount);
end;
$$;

create or replace function public.release_energy_reservation(
  p_user_id uuid, p_mode text, p_reason text, p_reference_id text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_row public.energy_reservations%rowtype; v_balance integer; v_tx uuid;
begin
  select * into v_row from public.energy_reservations
    where user_id = p_user_id and mode = p_mode and status = 'reserved'
      and (p_reference_id is null or reference_id = p_reference_id)
    order by created_at desc limit 1 for update;
  if not found then
    select energy_balance into v_balance from public.profiles where id = p_user_id;
    return jsonb_build_object('released', false, 'reason', 'not_reserved', 'energyBalance', v_balance);
  end if;
  if v_row.amount > 0 then
    update public.profiles set energy_balance = energy_balance + v_row.amount, updated_at = clock_timestamp()
      where id = p_user_id returning energy_balance into v_balance;
    insert into public.energy_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
      values (p_user_id, v_row.amount, 'entry_release', v_row.reference_id, 'release:' || v_row.id::text, v_balance)
      returning id into v_tx;
  else
    select energy_balance into v_balance from public.profiles where id = p_user_id;
  end if;
  update public.energy_reservations set status = 'released', released_at = clock_timestamp(),
    release_reason = p_reason, release_transaction_id = v_tx, expires_at = null where id = v_row.id;
  return jsonb_build_object('released', true, 'reservationId', v_row.id, 'energyBalance', v_balance, 'energyRefunded', v_row.amount);
end;
$$;

create or replace function public.release_expired_energy_reservations(p_limit integer default 200)
returns integer language plpgsql security definer set search_path = public as $$
declare v_row public.energy_reservations%rowtype; v_count integer := 0;
begin
  for v_row in select * from public.energy_reservations
    where status = 'reserved' and expires_at <= clock_timestamp()
    order by expires_at limit greatest(1, least(p_limit, 1000)) for update skip locked
  loop
    perform public.release_energy_reservation(v_row.user_id, v_row.mode, 'expired', v_row.reference_id);
    update public.energy_reservations set status = 'expired' where id = v_row.id and status = 'released';
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.grant_completion_energy(
  p_user_id uuid, p_reference_id text, p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_policy jsonb := public.active_economy_policy(); v_cap integer; v_reward integer;
  v_before integer; v_after integer; v_existing public.energy_transactions%rowtype;
begin
  perform public.apply_daily_energy_refill(p_user_id);
  select * into v_existing from public.energy_transactions
    where user_id = p_user_id and idempotency_key = p_idempotency_key;
  if found then return jsonb_build_object('energyAwarded', v_existing.delta, 'energyBalance', v_existing.balance_after, 'replayed', true); end if;
  select energy_balance into v_before from public.profiles where id = p_user_id for update;
  if public.has_active_pro(p_user_id) then
    return jsonb_build_object('energyAwarded', 0, 'energyBalance', v_before, 'unlimited', true, 'replayed', false);
  end if;
  v_cap := (v_policy #>> '{energy,freeCap}')::integer;
  v_reward := (v_policy #>> '{energy,completionReward}')::integer;
  v_after := least(v_cap, v_before + v_reward);
  if v_after > v_before then
    update public.profiles set energy_balance = v_after, updated_at = clock_timestamp() where id = p_user_id;
    insert into public.energy_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
      values (p_user_id, v_after - v_before, 'completion_reward', p_reference_id, p_idempotency_key, v_after);
  end if;
  return jsonb_build_object('energyAwarded', v_after - v_before, 'energyBalance', v_after, 'unlimited', false, 'replayed', false);
end;
$$;

create or replace function public.purchase_energy_pack(
  p_user_id uuid, p_package_id text, p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_policy jsonb := public.active_economy_policy(); v_pack jsonb; v_energy integer; v_cost integer;
  v_record public.api_idempotency_records%rowtype; v_hash text; v_coins integer; v_balance integer; v_response jsonb;
begin
  v_hash := encode(extensions.digest(jsonb_build_object('packageId', p_package_id)::text, 'sha256'), 'hex');
  select * into v_record from public.api_idempotency_records where user_id = p_user_id
    and operation = 'economy.energy_purchase' and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    return v_record.response;
  end if;
  select value into v_pack from jsonb_array_elements(v_policy #> '{energy,packs}') where value ->> 'id' = p_package_id;
  if v_pack is null then raise exception using errcode = 'P0001', message = 'NOT_FOUND: energy package'; end if;
  v_energy := (v_pack ->> 'energy')::integer; v_cost := (v_pack ->> 'yCoinCost')::integer;
  select coins, energy_balance into v_coins, v_balance from public.profiles where id = p_user_id for update;
  if v_coins < v_cost then raise exception using errcode = 'P0001', message = 'INSUFFICIENT_Y_COIN'; end if;
  update public.profiles set coins = coins - v_cost, energy_balance = energy_balance + v_energy, updated_at = clock_timestamp()
    where id = p_user_id returning coins, energy_balance into v_coins, v_balance;
  insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values (p_user_id, -v_cost, 'energy_purchase', p_package_id, 'energy-pack-coin:' || p_idempotency_key, v_coins);
  insert into public.energy_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values (p_user_id, v_energy, 'ycoin_purchase', p_package_id, 'energy-pack:' || p_idempotency_key, v_balance);
  v_response := jsonb_build_object('purchased', true, 'replayed', false, 'packageId', p_package_id,
    'energyAdded', v_energy, 'yCoinsCharged', v_cost, 'energyBalance', v_balance, 'yCoins', v_coins);
  insert into public.api_idempotency_records(user_id, operation, idempotency_key, request_hash, response)
    values (p_user_id, 'economy.energy_purchase', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

create or replace function public.activate_pro_beta(
  p_user_id uuid, p_plan_id text, p_skin_id text, p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_policy jsonb := public.active_economy_policy(); v_hash text; v_existing public.pro_entitlement_periods%rowtype;
  v_plan text; v_days integer; v_grant integer; v_unowned integer; v_period_id uuid; v_coin_tx uuid;
  v_coins integer; v_starts timestamptz := clock_timestamp(); v_ends timestamptz; v_response jsonb;
begin
  v_plan := v_policy #>> '{pro,planId}'; v_days := (v_policy #>> '{pro,durationDays}')::integer;
  v_grant := (v_policy #>> '{yCoin,proMonthlyGrant}')::integer;
  if p_plan_id <> v_plan then raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: planId'; end if;
  v_hash := encode(extensions.digest(jsonb_build_object('planId',p_plan_id,'skinId',p_skin_id)::text,'sha256'),'hex');
  select * into v_existing from public.pro_entitlement_periods where user_id = p_user_id and idempotency_key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    select coins into v_coins from public.profiles where id = p_user_id;
    return jsonb_build_object('activated', true, 'replayed', true, 'periodId', v_existing.id,
      'planId', v_existing.plan_id, 'startsAt', v_existing.starts_at, 'expiresAt', v_existing.ends_at,
      'selectedSkinId', v_existing.selected_skin_id, 'coinsGranted', v_grant, 'yCoins', v_coins);
  end if;
  perform 1 from public.profiles where id = p_user_id for update;
  if public.has_active_pro(p_user_id, v_starts) then raise exception using errcode = 'P0001', message = 'PRO_ALREADY_ACTIVE'; end if;
  select count(*) into v_unowned from jsonb_array_elements_text(v_policy #> '{pro,exclusiveSkinIds}') skin(id)
    where not exists (select 1 from public.user_inventory where user_id = p_user_id and item_id = skin.id);
  if v_unowned > 0 then
    if p_skin_id is null or not (v_policy #> '{pro,exclusiveSkinIds}') ? p_skin_id
      or exists (select 1 from public.user_inventory where user_id = p_user_id and item_id = p_skin_id) then
      raise exception using errcode = 'P0001', message = 'PRO_SKIN_NOT_ELIGIBLE';
    end if;
  else
    p_skin_id := null;
  end if;
  v_ends := v_starts + make_interval(days => v_days);
  update public.profiles set coins = coins + v_grant, updated_at = v_starts where id = p_user_id returning coins into v_coins;
  v_period_id := gen_random_uuid();
  insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after, created_at)
    values (p_user_id, v_grant, 'pro_monthly_grant', v_period_id::text, 'pro:' || p_idempotency_key, v_coins, v_starts)
    returning id into v_coin_tx;
  insert into public.pro_entitlement_periods(id,user_id,plan_id,source,status,starts_at,ends_at,selected_skin_id,coin_transaction_id,idempotency_key,request_hash)
    values (v_period_id,p_user_id,p_plan_id,'beta','active',v_starts,v_ends,p_skin_id,v_coin_tx,p_idempotency_key,v_hash);
  if p_skin_id is not null then
    insert into public.user_inventory(user_id,item_id,source,source_ref)
      values (p_user_id,p_skin_id,'pro',v_period_id::text) on conflict (user_id,item_id) do nothing;
  end if;
  v_response := jsonb_build_object('activated',true,'replayed',false,'periodId',v_period_id,'planId',p_plan_id,
    'startsAt',v_starts,'expiresAt',v_ends,'selectedSkinId',p_skin_id,'coinsGranted',v_grant,'yCoins',v_coins);
  return v_response;
end;
$$;

create or replace function public.claim_verified_ad_reward(
  p_user_id uuid, p_reward_type text, p_placement_id text, p_provider text,
  p_provider_transaction_id text, p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_policy jsonb := public.active_economy_policy(); v_date date := public.wib_business_date(clock_timestamp());
  v_limit integer; v_amount integer; v_count integer; v_energy integer; v_coins integer; v_award integer;
  v_energy_tx uuid; v_coin_tx uuid; v_claim public.ad_reward_claims%rowtype;
begin
  if p_reward_type not in ('energy','y_coin') then raise exception using errcode='P0001', message='VALIDATION_FAILED: rewardType'; end if;
  select * into v_claim from public.ad_reward_claims where user_id=p_user_id and idempotency_key=p_idempotency_key;
  if found then return jsonb_build_object('claimed',true,'replayed',true,'rewardType',v_claim.reward_type,'amountAwarded',v_claim.amount_awarded); end if;
  v_limit := case when p_reward_type='energy' then (v_policy #>> '{energy,adDailyLimit}')::integer else (v_policy #>> '{yCoin,adDailyLimit}')::integer end;
  v_amount := case when p_reward_type='energy' then (v_policy #>> '{energy,adReward}')::integer else (v_policy #>> '{yCoin,adReward}')::integer end;
  select count(*) into v_count from public.ad_reward_claims where user_id=p_user_id and reward_type=p_reward_type and business_date=v_date;
  if v_count >= v_limit then raise exception using errcode='P0001', message='AD_REWARD_LIMIT_REACHED'; end if;
  perform public.apply_daily_energy_refill(p_user_id);
  select energy_balance, coins into v_energy, v_coins from public.profiles where id=p_user_id for update;
  if p_reward_type='energy' then
    v_award := greatest(0, least(v_amount, (v_policy #>> '{energy,freeCap}')::integer - v_energy));
    if v_award = 0 then raise exception using errcode='P0001', message='ENERGY_CAP_REACHED'; end if;
    update public.profiles set energy_balance=energy_balance+v_award,updated_at=clock_timestamp() where id=p_user_id returning energy_balance into v_energy;
    insert into public.energy_transactions(user_id,delta,reason,reference_id,idempotency_key,balance_after)
      values(p_user_id,v_award,'ad_reward',p_provider_transaction_id,'ad-energy:'||p_idempotency_key,v_energy) returning id into v_energy_tx;
  else
    v_award := v_amount;
    update public.profiles set coins=coins+v_award,updated_at=clock_timestamp() where id=p_user_id returning coins into v_coins;
    insert into public.coin_transactions(user_id,delta,reason,reference_id,idempotency_key,balance_after)
      values(p_user_id,v_award,'ad_reward',p_provider_transaction_id,'ad-coin:'||p_idempotency_key,v_coins) returning id into v_coin_tx;
  end if;
  insert into public.ad_reward_claims(user_id,reward_type,placement_id,provider,provider_transaction_id,idempotency_key,business_date,amount_awarded,energy_transaction_id,coin_transaction_id)
    values(p_user_id,p_reward_type,p_placement_id,p_provider,p_provider_transaction_id,p_idempotency_key,v_date,v_award,v_energy_tx,v_coin_tx);
  return jsonb_build_object('claimed',true,'replayed',false,'rewardType',p_reward_type,'amountAwarded',v_award,'energyBalance',v_energy,'yCoins',v_coins);
end;
$$;

create or replace function public.create_interview_session_with_charge(
  p_user_id uuid, p_idempotency_key text, p_company_id text, p_target_role text,
  p_mode text, p_language text, p_response_style text, p_context_snapshot jsonb,
  p_opening_question text
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_policy jsonb := public.active_economy_policy(); v_cost integer; v_hash text;
  v_existing public.interview_session_charges%rowtype; v_session_id uuid; v_turn_id uuid;
  v_coins integer; v_coin_tx uuid;
begin
  v_cost := (v_policy #>> '{yCoin,interviewCost}')::integer;
  v_hash := encode(extensions.digest(jsonb_build_object('companyId',p_company_id,'targetRole',p_target_role,
    'mode',p_mode,'language',p_language,'responseStyle',p_response_style)::text,'sha256'),'hex');
  select * into v_existing from public.interview_session_charges where user_id=p_user_id and idempotency_key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception using errcode='P0001',message='IDEMPOTENCY_KEY_REUSED'; end if;
    select coins into v_coins from public.profiles where id=p_user_id;
    select id into v_turn_id from public.interview_turns where session_id=v_existing.session_id and role='question' order by created_at limit 1;
    return jsonb_build_object('sessionId',v_existing.session_id,'openingQuestionId',v_turn_id,'chargedYCoins',v_existing.amount,'yCoins',v_coins,'replayed',true);
  end if;
  select coins into v_coins from public.profiles where id=p_user_id for update;
  if v_coins<v_cost then raise exception using errcode='P0001',message='INSUFFICIENT_Y_COIN'; end if;
  insert into public.interview_sessions(user_id,company_id,target_role,mode,language,response_style,context_snapshot)
    values(p_user_id,p_company_id,p_target_role,p_mode,p_language,p_response_style,p_context_snapshot) returning id into v_session_id;
  insert into public.interview_turns(session_id,role,content) values(v_session_id,'question',p_opening_question) returning id into v_turn_id;
  update public.profiles set coins=coins-v_cost,updated_at=clock_timestamp() where id=p_user_id returning coins into v_coins;
  insert into public.coin_transactions(user_id,delta,reason,reference_id,idempotency_key,balance_after)
    values(p_user_id,-v_cost,'interview_session',v_session_id::text,'interview:'||p_idempotency_key,v_coins) returning id into v_coin_tx;
  insert into public.interview_session_charges(user_id,session_id,amount,idempotency_key,request_hash,coin_transaction_id)
    values(p_user_id,v_session_id,v_cost,p_idempotency_key,v_hash,v_coin_tx);
  return jsonb_build_object('sessionId',v_session_id,'openingQuestionId',v_turn_id,'chargedYCoins',v_cost,'yCoins',v_coins,'replayed',false);
end;
$$;

create or replace function public.purchase_store_item(p_user_id uuid,p_item_id text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_item public.store_items%rowtype; v_existing public.store_purchases%rowtype; v_purchase_id uuid; v_balance integer;
begin
  if nullif(btrim(p_idempotency_key),'') is null then raise exception using errcode='P0001',message='VALIDATION_FAILED: idempotencyKey'; end if;
  select * into v_existing from public.store_purchases where user_id=p_user_id and idempotency_key=p_idempotency_key;
  if found then
    if v_existing.item_id<>p_item_id then raise exception using errcode='P0001',message='IDEMPOTENCY_KEY_REUSED'; end if;
    select coins into v_balance from public.profiles where id=p_user_id;
    return jsonb_build_object('purchased',false,'replayed',true,'purchaseId',v_existing.id,'itemId',v_existing.item_id,'coins',v_balance);
  end if;
  select * into v_item from public.store_items where id=p_item_id and is_active for update;
  if not found then raise exception using errcode='P0001',message='NOT_FOUND: store item'; end if;
  if v_item.is_pro_exclusive then raise exception using errcode='P0001',message='ACTION_REJECTED: Store item is YUDHA Pro exclusive.'; end if;
  if exists(select 1 from public.user_inventory where user_id=p_user_id and item_id=p_item_id) then raise exception using errcode='P0001',message='CONFLICT: Store item is already owned.'; end if;
  select coins into v_balance from public.profiles where id=p_user_id for update;
  if v_balance<v_item.coin_price then raise exception using errcode='P0001',message='INSUFFICIENT_Y_COIN'; end if;
  update public.profiles set coins=coins-v_item.coin_price where id=p_user_id returning coins into v_balance;
  insert into public.store_purchases(user_id,item_id,idempotency_key,price_paid) values(p_user_id,p_item_id,p_idempotency_key,v_item.coin_price) returning id into v_purchase_id;
  insert into public.user_inventory(user_id,item_id,source,source_ref) values(p_user_id,p_item_id,'purchase',v_purchase_id::text);
  if v_item.coin_price>0 then insert into public.coin_transactions(user_id,delta,reason,reference_id,idempotency_key,balance_after)
    values(p_user_id,-v_item.coin_price,'store_purchase',v_purchase_id::text,'store-purchase:'||p_idempotency_key,v_balance); end if;
  return jsonb_build_object('purchased',true,'replayed',false,'purchaseId',v_purchase_id,'itemId',p_item_id,'coins',v_balance);
end;
$$;

-- Triggers keep compatibility and canonical learning flows atomic without
-- duplicating their mature selection/finalization functions.
create or replace function public.consume_session_entry_energy()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_mode text; v_result jsonb;
begin
  v_mode := case TG_TABLE_NAME when 'solo_sessions' then 'solo' else 'practice' end;
  v_result := public.reserve_energy(NEW.user_id,v_mode,NEW.id::text,
    v_mode||'-session:'||NEW.id::text,900,true);
  return NEW;
end;
$$;
drop trigger if exists solo_session_energy_entry on public.solo_sessions;
create trigger solo_session_energy_entry before insert on public.solo_sessions
  for each row execute function public.consume_session_entry_energy();
drop trigger if exists practice_session_energy_entry on public.practice_sessions;
create trigger practice_session_energy_entry before insert on public.practice_sessions
  for each row execute function public.consume_session_entry_energy();

create or replace function public.reward_completed_session_energy()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_complete boolean; v_reference text;
begin
  if TG_TABLE_NAME='solo_sessions' then
    v_complete := OLD.status='active' and NEW.status='completed' and NEW.completion_reason='policy_completed';
  else
    v_complete := OLD.finished_at is null and NEW.finished_at is not null
      and NEW.total_questions>0
      and (select count(*) from public.practice_answers where session_id=NEW.id)>=NEW.total_questions;
  end if;
  if v_complete then
    v_reference := TG_TABLE_NAME||':'||NEW.id::text;
    perform public.grant_completion_energy(NEW.user_id,v_reference,'completion-energy:'||v_reference);
  end if;
  return NEW;
end;
$$;
drop trigger if exists solo_session_energy_completion on public.solo_sessions;
create trigger solo_session_energy_completion after update on public.solo_sessions
  for each row execute function public.reward_completed_session_energy();
drop trigger if exists practice_session_energy_completion on public.practice_sessions;
create trigger practice_session_energy_completion after update on public.practice_sessions
  for each row execute function public.reward_completed_session_energy();

create or replace function public.charge_hint_ycoins()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_user uuid; v_cost integer := (public.active_economy_policy() #>> '{yCoin,hintCost}')::integer;
  v_balance integer; v_tx uuid; v_key text;
begin
  if OLD.hint_requested_at is not null or NEW.hint_requested_at is null then return NEW; end if;
  if TG_TABLE_NAME='solo_session_questions' then select user_id into v_user from public.solo_sessions where id=NEW.session_id;
  else select user_id into v_user from public.practice_sessions where id=NEW.session_id; end if;
  v_key := 'hint:'||TG_TABLE_NAME||':'||NEW.id::text;
  if exists(select 1 from public.coin_transactions where user_id=v_user and idempotency_key=v_key) then return NEW; end if;
  select coins into v_balance from public.profiles where id=v_user for update;
  if v_balance<v_cost then raise exception using errcode='P0001',message='INSUFFICIENT_Y_COIN'; end if;
  update public.profiles set coins=coins-v_cost,updated_at=clock_timestamp() where id=v_user returning coins into v_balance;
  insert into public.coin_transactions(user_id,delta,reason,reference_id,idempotency_key,balance_after)
    values(v_user,-v_cost,'admin',NEW.id::text,v_key,v_balance) returning id into v_tx;
  return NEW;
end;
$$;
drop trigger if exists solo_hint_ycoin_charge on public.solo_session_questions;
create trigger solo_hint_ycoin_charge before update of hint_requested_at on public.solo_session_questions
  for each row execute function public.charge_hint_ycoins();
drop trigger if exists practice_hint_ycoin_charge on public.practice_session_questions;
create trigger practice_hint_ycoin_charge before update of hint_requested_at on public.practice_session_questions
  for each row execute function public.charge_hint_ycoins();

create or replace function public.reward_match_economy()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_normal boolean; v_user uuid; v_balance integer; v_reward integer;
begin
  v_normal := NEW.reason in ('hp_zero','round_timeout','question_exhaustion','draw');
  if v_normal and NEW.mode in ('bot','casual','ranked') then
    perform public.grant_completion_energy(NEW.player_a_id,'match:'||NEW.id::text,'completion-energy:match:'||NEW.id::text||':a');
    if NEW.player_b_id is not null then perform public.grant_completion_energy(NEW.player_b_id,'match:'||NEW.id::text,'completion-energy:match:'||NEW.id::text||':b'); end if;
  end if;
  if v_normal and NEW.mode='casual' then
    v_reward := (public.active_economy_policy() #>> '{yCoin,casualCompletionReward}')::integer;
    foreach v_user in array array[NEW.player_a_id,NEW.player_b_id] loop
      if v_user is not null then
        update public.profiles set coins=coins+v_reward,updated_at=NEW.ended_at where id=v_user returning coins into v_balance;
        insert into public.coin_transactions(user_id,delta,reason,reference_id,idempotency_key,balance_after,created_at)
          values(v_user,v_reward,'match_reward',NEW.room_id,'casual:'||NEW.id::text||':'||v_user::text,v_balance,NEW.ended_at);
      end if;
    end loop;
  end if;
  return NEW;
end;
$$;
drop trigger if exists match_result_economy_reward on public.match_results;
create trigger match_result_economy_reward after insert on public.match_results
  for each row execute function public.reward_match_economy();

-- Daily missions remain engagement state, not a Y-Coin source.
create or replace function public.apply_daily_mission(
  p_user_id uuid,p_mission_key text,p_source_type text,p_source_id text,
  p_completed_at timestamptz default clock_timestamp()
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_date date:=public.wib_business_date(p_completed_at); v_balance integer;
begin
  if p_mission_key not in ('daily_practice','daily_pvp') then raise exception using errcode='P0001',message='VALIDATION_FAILED: unsupported daily mission'; end if;
  select coins into v_balance from public.profiles where id=p_user_id;
  if exists(select 1 from public.daily_mission_progress where user_id=p_user_id and mission_key=p_mission_key and business_date=v_date) then
    return jsonb_build_object('key',p_mission_key,'businessDate',v_date,'awarded',false,'rewardYCoins',0,'yCoins',v_balance);
  end if;
  insert into public.daily_mission_progress(user_id,mission_key,business_date,source_type,source_id,completed_at,reward_rank_points,reward_ycoins)
    values(p_user_id,p_mission_key,v_date,p_source_type,p_source_id,p_completed_at,0,0);
  return jsonb_build_object('key',p_mission_key,'businessDate',v_date,'awarded',true,'rewardYCoins',0,'yCoins',v_balance);
end;
$$;

-- Existing finalized functions reference this symbol. Keep a private no-op shim
-- while removing every Hired Pass table, route and mutation.
create or replace function public.record_hired_pass_activity(
  p_user_id uuid,p_event_type text,p_source_id text,p_occurred_at timestamptz default now()
)
returns jsonb language sql security definer set search_path=public as $$
  select jsonb_build_object('applied',false,'removed',true)
$$;

drop trigger if exists interview_hired_pass_completion on public.interview_sessions;
drop trigger if exists practice_hired_pass_completion on public.practice_sessions;
drop function if exists public.record_interview_hired_pass_completion();
drop function if exists public.record_practice_hired_pass_completion();
drop function if exists public.claim_hired_pass_reward_idempotent(uuid,text,text);
drop function if exists public.activate_hired_pass_beta(uuid,text,text);
drop function if exists public.claim_hired_pass_reward(uuid,text);

drop table if exists public.user_hired_pass_reward_claims cascade;
drop table if exists public.user_hired_pass_mission_progress cascade;
drop table if exists public.user_hired_pass_progress cascade;
drop table if exists public.hired_pass_activity_events cascade;
drop table if exists public.hired_pass_rewards cascade;
drop table if exists public.hired_pass_missions cascade;
drop table if exists public.hired_pass_seasons cascade;
alter table public.profiles drop column if exists hired_pass_expires_at;

revoke all on function public.active_economy_policy() from public,anon,authenticated;
revoke all on function public.has_active_pro(uuid,timestamptz) from public,anon,authenticated;
revoke all on function public.apply_daily_energy_refill(uuid,timestamptz) from public,anon,authenticated;
revoke all on function public.get_economy_state(uuid,timestamptz) from public,anon,authenticated;
revoke all on function public.reserve_energy(uuid,text,text,text,integer,boolean) from public,anon,authenticated;
revoke all on function public.commit_energy_reservation(uuid,text,text) from public,anon,authenticated;
revoke all on function public.release_energy_reservation(uuid,text,text,text) from public,anon,authenticated;
revoke all on function public.release_expired_energy_reservations(integer) from public,anon,authenticated;
revoke all on function public.grant_completion_energy(uuid,text,text) from public,anon,authenticated;
revoke all on function public.purchase_energy_pack(uuid,text,text) from public,anon,authenticated;
revoke all on function public.activate_pro_beta(uuid,text,text,text) from public,anon,authenticated;
revoke all on function public.claim_verified_ad_reward(uuid,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.create_interview_session_with_charge(uuid,text,text,text,text,text,text,jsonb,text) from public,anon,authenticated;

grant execute on function public.active_economy_policy() to service_role;
grant execute on function public.has_active_pro(uuid,timestamptz) to service_role;
grant execute on function public.apply_daily_energy_refill(uuid,timestamptz) to service_role;
grant execute on function public.get_economy_state(uuid,timestamptz) to service_role;
grant execute on function public.reserve_energy(uuid,text,text,text,integer,boolean) to service_role;
grant execute on function public.commit_energy_reservation(uuid,text,text) to service_role;
grant execute on function public.release_energy_reservation(uuid,text,text,text) to service_role;
grant execute on function public.release_expired_energy_reservations(integer) to service_role;
grant execute on function public.grant_completion_energy(uuid,text,text) to service_role;
grant execute on function public.purchase_energy_pack(uuid,text,text) to service_role;
grant execute on function public.activate_pro_beta(uuid,text,text,text) to service_role;
grant execute on function public.claim_verified_ad_reward(uuid,text,text,text,text,text) to service_role;
grant execute on function public.create_interview_session_with_charge(uuid,text,text,text,text,text,text,jsonb,text) to service_role;

commit;
