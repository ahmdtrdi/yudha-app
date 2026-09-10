begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();
update beta_welcome_campaigns set starts_at = '2026-09-10T00:00:00Z', enabled = true;

insert into auth.users(id, email, created_at, raw_user_meta_data) values
 ('ba000000-0000-0000-0000-000000000001', 'beta-new@example.test', '2026-09-11', '{"target":"cpns"}'),
 ('ba000000-0000-0000-0000-000000000002', 'beta-old@example.test', '2026-09-09', '{"target":"cpns"}');
-- The recovered public-schema dump does not always include auth.users triggers.
insert into profiles(id, username, target) values
 ('ba000000-0000-0000-0000-000000000001', 'beta-new', 'cpns'),
 ('ba000000-0000-0000-0000-000000000002', 'beta-old', 'cpns') on conflict (id) do nothing;
select is((select coins from profiles where id='ba000000-0000-0000-0000-000000000001'), 1000, 'adds 1000 coins');
select is((select energy_balance from profiles where id='ba000000-0000-0000-0000-000000000001'), 1010, 'adds 1000 energy to starting 10');
select is((select count(*)::integer from beta_welcome_rewards where user_id='ba000000-0000-0000-0000-000000000002'), 0, 'existing accounts excluded');
select grant_beta_welcome_reward('ba000000-0000-0000-0000-000000000001');
select is((select count(*)::integer from coin_transactions where user_id='ba000000-0000-0000-0000-000000000001' and reason='beta_credit'), 1, 'replay cannot duplicate coins');
select is((select count(*)::integer from energy_transactions where user_id='ba000000-0000-0000-0000-000000000001' and reason='beta_credit'), 1, 'replay cannot duplicate energy');
select apply_daily_energy_refill('ba000000-0000-0000-0000-000000000001', clock_timestamp() + interval '2 days');
select is((select energy_balance from profiles where id='ba000000-0000-0000-0000-000000000001'), 1010, 'daily refill preserves bonus');
select ok(get_beta_welcome_reward('ba000000-0000-0000-0000-000000000001')->>'acknowledgedAt' is null, 'unconfirmed email account reward waits for lobby acknowledgment');
select acknowledge_beta_welcome_reward('ba000000-0000-0000-0000-000000000001');
select ok(get_beta_welcome_reward('ba000000-0000-0000-0000-000000000001')->>'acknowledgedAt' is not null, 'acknowledgment persists');
select is(acknowledge_beta_welcome_reward('ba000000-0000-0000-0000-000000000001'), get_beta_welcome_reward('ba000000-0000-0000-0000-000000000001'), 'acknowledgment replay is stable');
select reset_user_account_data('ba000000-0000-0000-0000-000000000001');
select is((select coins from profiles where id='ba000000-0000-0000-0000-000000000001'), 0, 'profile reset does not regrant');
select is((select count(*)::integer from beta_welcome_rewards where user_id='ba000000-0000-0000-0000-000000000001'), 1, 'grant survives profile reset');

update beta_welcome_campaigns set enabled = false;
insert into auth.users(id,email,created_at,raw_user_meta_data) values
 ('ba000000-0000-0000-0000-000000000003','beta-disabled@example.test','2026-09-11','{"target":"cpns"}');
insert into profiles(id,username,target) values ('ba000000-0000-0000-0000-000000000003','beta-disabled','cpns') on conflict(id) do nothing;
select is((select coins from profiles where id='ba000000-0000-0000-0000-000000000003'), 0, 'disabled campaign grants nothing');

-- Force failure of the second ledger write to prove all-or-nothing crediting.
update beta_welcome_campaigns set enabled = true;
create function pg_temp.reject_beta_energy() returns trigger language plpgsql as $$
begin raise exception 'test energy failure'; end $$;
create trigger test_reject_beta_energy before insert on energy_transactions for each row execute function pg_temp.reject_beta_energy();
select throws_ok($$select grant_beta_welcome_reward('ba000000-0000-0000-0000-000000000003')$$, 'P0001', 'test energy failure', 'energy ledger failure rolls back grant');
select is((select coins from profiles where id='ba000000-0000-0000-0000-000000000003'), 0, 'coin balance rolled back');
select is((select count(*)::integer from beta_welcome_rewards where user_id='ba000000-0000-0000-0000-000000000003'), 0, 'grant record rolled back');
select ok(not has_function_privilege('authenticated','public.grant_beta_welcome_reward(uuid)','EXECUTE'), 'clients cannot grant rewards');
select ok(not has_function_privilege('authenticated','public.acknowledge_beta_welcome_reward(uuid)','EXECUTE'), 'clients cannot acknowledge other users through RPC');
select * from finish();
rollback;
