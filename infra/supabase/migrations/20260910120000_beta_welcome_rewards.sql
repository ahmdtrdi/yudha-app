begin;

create table public.beta_welcome_campaigns (
  id text primary key,
  starts_at timestamptz not null,
  enabled boolean not null default false,
  coin_amount integer not null check (coin_amount > 0),
  energy_amount integer not null check (energy_amount > 0)
);

-- Activation is the migration's installation time, never a client timestamp.
insert into public.beta_welcome_campaigns values
  ('beta-welcome-v1', clock_timestamp(), true, 1000, 1000);

create table public.beta_welcome_rewards (
  id uuid primary key default gen_random_uuid(),
  -- Survive a profile/data reset, but disappear when the auth account is deleted.
  user_id uuid not null references auth.users(id) on delete cascade,
  campaign_id text not null references public.beta_welcome_campaigns(id),
  coin_amount integer not null,
  energy_amount integer not null,
  granted_at timestamptz not null default clock_timestamp(),
  acknowledged_at timestamptz,
  unique (user_id, campaign_id)
);

alter table public.beta_welcome_campaigns enable row level security;
alter table public.beta_welcome_rewards enable row level security;
revoke all on public.beta_welcome_campaigns, public.beta_welcome_rewards from anon, authenticated;
grant all on public.beta_welcome_campaigns, public.beta_welcome_rewards to service_role;

alter table public.energy_transactions drop constraint energy_transactions_reason_check;
alter table public.energy_transactions add constraint energy_transactions_reason_check
  check (reason in ('daily_refill', 'entry_reserve', 'entry_release',
    'completion_reward', 'ad_reward', 'ycoin_purchase', 'admin', 'beta_credit'));

create function public.grant_beta_welcome_reward(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_campaign public.beta_welcome_campaigns%rowtype;
  v_reward_id uuid;
  v_coins integer;
  v_energy integer;
begin
  -- Serialize against purchases/refills and repeat grants for this account.
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then return; end if;
  select c.* into v_campaign from public.beta_welcome_campaigns c
    join auth.users u on u.id = p_user_id
    where c.id = 'beta-welcome-v1' and c.enabled and u.created_at >= c.starts_at
    for share of c;
  if not found then return; end if;

  insert into public.beta_welcome_rewards(user_id, campaign_id, coin_amount, energy_amount)
    values (p_user_id, v_campaign.id, v_campaign.coin_amount, v_campaign.energy_amount)
    on conflict (user_id, campaign_id) do nothing returning id into v_reward_id;
  if v_reward_id is null then return; end if;

  update public.profiles set coins = coins + v_campaign.coin_amount,
    energy_balance = energy_balance + v_campaign.energy_amount
    where id = p_user_id returning coins, energy_balance into v_coins, v_energy;
  insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values (p_user_id, v_campaign.coin_amount, 'beta_credit', v_reward_id::text,
      'beta-welcome:' || v_campaign.id, v_coins);
  insert into public.energy_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values (p_user_id, v_campaign.energy_amount, 'beta_credit', v_reward_id::text,
      'beta-welcome:' || v_campaign.id, v_energy);
end;
$$;

create function public.on_profile_beta_welcome()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.grant_beta_welcome_reward(new.id);
  return new;
end;
$$;
create trigger profile_beta_welcome after insert on public.profiles
  for each row execute function public.on_profile_beta_welcome();

create function public.get_beta_welcome_reward(p_user_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', id, 'coinAmount', coin_amount,
    'energyAmount', energy_amount, 'grantedAt', granted_at,
    'acknowledgedAt', acknowledged_at)
  from public.beta_welcome_rewards
  where user_id = p_user_id and campaign_id = 'beta-welcome-v1';
$$;

create function public.acknowledge_beta_welcome_reward(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  update public.beta_welcome_rewards
    set acknowledged_at = coalesce(acknowledged_at, clock_timestamp())
    where user_id = p_user_id and campaign_id = 'beta-welcome-v1';
  return public.get_beta_welcome_reward(p_user_id);
end;
$$;

revoke all on function public.grant_beta_welcome_reward(uuid),
  public.on_profile_beta_welcome(), public.get_beta_welcome_reward(uuid),
  public.acknowledge_beta_welcome_reward(uuid) from public, anon, authenticated;
grant execute on function public.grant_beta_welcome_reward(uuid),
  public.get_beta_welcome_reward(uuid), public.acknowledge_beta_welcome_reward(uuid) to service_role;

commit;
