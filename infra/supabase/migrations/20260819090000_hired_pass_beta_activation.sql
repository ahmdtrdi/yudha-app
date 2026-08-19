create or replace function public.activate_hired_pass_beta(
  p_user_id uuid,
  p_season_id text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_season public.hired_pass_seasons%rowtype;
  v_expires_at timestamptz;
  v_existing jsonb;
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(trim(p_idempotency_key)) = 0
     or char_length(p_idempotency_key) > 160 then
    raise exception 'idempotencyKey is required.';
  end if;

  select response into v_existing
  from public.api_idempotency_records
  where user_id = p_user_id
    and operation = 'hired_pass_beta_activate'
    and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;

  select * into v_season
  from public.hired_pass_seasons
  where id = p_season_id
    and is_active
    and now() >= starts_at
    and now() < ends_at;
  if not found then
    raise exception 'Hired Pass season is not available.';
  end if;

  v_expires_at := v_season.ends_at;
  update public.profiles
  set hired_pass_expires_at = greatest(coalesce(hired_pass_expires_at, v_expires_at), v_expires_at),
      updated_at = now()
  where id = p_user_id;
  if not found then
    raise exception 'Profile not found.';
  end if;

  v_response := jsonb_build_object(
    'activated', true,
    'replayed', false,
    'entitlement', jsonb_build_object(
      'premiumActive', true,
      'expiresAt', v_expires_at
    )
  );

  insert into public.api_idempotency_records
    (user_id, operation, idempotency_key, request_hash, response)
  values
    (p_user_id, 'hired_pass_beta_activate', p_idempotency_key, p_season_id, v_response);

  return v_response;
end;
$$;

revoke all on function public.activate_hired_pass_beta(uuid, text, text) from public;
grant execute on function public.activate_hired_pass_beta(uuid, text, text) to service_role;

create or replace function public.claim_hired_pass_reward_idempotent(
  p_user_id uuid,
  p_reward_id text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing jsonb;
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(trim(p_idempotency_key)) = 0
     or char_length(p_idempotency_key) > 160 then
    raise exception 'idempotencyKey is required.';
  end if;

  select response into v_existing
  from public.api_idempotency_records
  where user_id = p_user_id
    and operation = 'hired_pass_reward_claim'
    and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;

  v_response := public.claim_hired_pass_reward(p_user_id, p_reward_id);
  insert into public.api_idempotency_records
    (user_id, operation, idempotency_key, request_hash, response)
  values
    (p_user_id, 'hired_pass_reward_claim', p_idempotency_key, p_reward_id, v_response);

  return v_response || jsonb_build_object('replayed', false);
end;
$$;

revoke all on function public.claim_hired_pass_reward_idempotent(uuid, text, text) from public;
grant execute on function public.claim_hired_pass_reward_idempotent(uuid, text, text) to service_role;