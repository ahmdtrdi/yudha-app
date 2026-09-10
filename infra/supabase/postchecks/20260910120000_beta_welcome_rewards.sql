-- Read-only verification for Supabase Cloud SQL Editor.
select 'beta campaign exists' as check_name,
  exists(select 1 from public.beta_welcome_campaigns where id='beta-welcome-v1'
    and starts_at is not null and coin_amount=1000 and energy_amount=1000) as passed
union all
select 'profile provisioning grants beta rewards', exists(
  select 1 from pg_trigger where tgrelid='public.profiles'::regclass
    and tgname='profile_beta_welcome' and tgenabled='O')
union all
select 'account signup creates profiles', exists(
  select 1 from pg_trigger where tgrelid='auth.users'::regclass
    and tgfoid='public.handle_new_user()'::regprocedure and tgenabled='O')
union all
select 'reward records are protected by RLS', relrowsecurity
  from pg_class where oid='public.beta_welcome_rewards'::regclass
union all
select 'authenticated clients cannot grant',
  not has_function_privilege('authenticated','public.grant_beta_welcome_reward(uuid)','EXECUTE')
union all
select 'authenticated clients cannot acknowledge arbitrary accounts',
  not has_function_privilege('authenticated','public.acknowledge_beta_welcome_reward(uuid)','EXECUTE')
union all
select 'backend can read and acknowledge rewards',
  has_function_privilege('service_role','public.get_beta_welcome_reward(uuid)','EXECUTE') and
  has_function_privilege('service_role','public.acknowledge_beta_welcome_reward(uuid)','EXECUTE')
union all
select 'no duplicate account grants', not exists(
  select user_id,campaign_id from public.beta_welcome_rewards group by user_id,campaign_id having count(*)>1);

select id, starts_at, enabled, coin_amount, energy_amount from public.beta_welcome_campaigns;
