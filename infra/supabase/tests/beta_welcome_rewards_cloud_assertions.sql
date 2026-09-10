-- Include after the migration inside a transaction that ends with ROLLBACK.
-- Random disposable account IDs; no real learner records are modified.
do $$
declare
  v_new uuid := gen_random_uuid();
  v_old uuid := gen_random_uuid();
  v_disabled uuid := gen_random_uuid();
  v_ack jsonb;
  v_start timestamptz;
begin
  select starts_at into v_start from public.beta_welcome_campaigns where id='beta-welcome-v1';
  insert into auth.users(id,email,created_at,raw_user_meta_data) values
    (v_new, v_new::text || '@example.test', v_start + interval '1 second', '{"target":"cpns"}'),
    (v_old, v_old::text || '@example.test', v_start - interval '1 day', '{"target":"cpns"}');
  if (select coins <> 1000 or energy_balance <> 1010 from public.profiles where id=v_new) then
    raise exception 'New account balances incorrect';
  end if;
  if not exists(select 1 from public.profiles where id=v_new) then raise exception 'Signup trigger failed'; end if;
  if exists(select 1 from public.beta_welcome_rewards where user_id=v_old) then raise exception 'Old account granted'; end if;
  perform public.grant_beta_welcome_reward(v_new);
  if (select count(*) from public.coin_transactions where user_id=v_new and reason='beta_credit') <> 1 or
     (select count(*) from public.energy_transactions where user_id=v_new and reason='beta_credit') <> 1 then
    raise exception 'Repeated grant duplicated ledger entries';
  end if;
  perform public.apply_daily_energy_refill(v_new, clock_timestamp() + interval '2 days');
  if (select energy_balance from public.profiles where id=v_new) <> 1010 then raise exception 'Refill lost bonus'; end if;
  if public.get_beta_welcome_reward(v_new)->>'acknowledgedAt' is not null then raise exception 'Premature acknowledgment'; end if;
  v_ack := public.acknowledge_beta_welcome_reward(v_new);
  if v_ack->>'acknowledgedAt' is null or v_ack is distinct from public.acknowledge_beta_welcome_reward(v_new) then
    raise exception 'Acknowledgment is not durable/idempotent';
  end if;
  perform public.reset_user_account_data(v_new);
  if (select coins from public.profiles where id=v_new) <> 0 or
    (select count(*) from public.beta_welcome_rewards where user_id=v_new) <> 1 then raise exception 'Profile reset regranted reward'; end if;

  update public.beta_welcome_campaigns set enabled=false where id='beta-welcome-v1';
  insert into auth.users(id,email,created_at,raw_user_meta_data) values
    (v_disabled,v_disabled::text || '@example.test',v_start + interval '1 second','{"target":"cpns"}');
  if exists(select 1 from public.beta_welcome_rewards where user_id=v_disabled) then raise exception 'Disabled campaign granted'; end if;
  update public.beta_welcome_campaigns set enabled=true where id='beta-welcome-v1';
  -- Cause the second ledger insert to fail, after the coin update has run.
  insert into public.energy_transactions(user_id,delta,reason,idempotency_key,balance_after)
    values(v_disabled,1,'admin','beta-welcome:beta-welcome-v1',10);
  begin
    perform public.grant_beta_welcome_reward(v_disabled);
    raise exception 'Expected ledger uniqueness failure';
  exception when unique_violation then null;
  end;
  if exists(select 1 from public.beta_welcome_rewards where user_id=v_disabled) or
    (select coins from public.profiles where id=v_disabled) <> 0 or
    exists(select 1 from public.coin_transactions where user_id=v_disabled and reason='beta_credit') then
    raise exception 'Partial grant was not rolled back';
  end if;
  if has_function_privilege('authenticated','public.grant_beta_welcome_reward(uuid)','EXECUTE') or
     has_function_privilege('authenticated','public.acknowledge_beta_welcome_reward(uuid)','EXECUTE') then
    raise exception 'Client can mutate arbitrary account rewards';
  end if;
end;
$$;
