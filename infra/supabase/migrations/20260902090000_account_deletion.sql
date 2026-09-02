create or replace function public.reset_user_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text;
  v_full_name text;
  v_target text;
  v_created_at timestamptz;
begin
  select username, full_name, target, created_at
    into v_username, v_full_name, v_target, v_created_at
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  -- Interview sessions reference auth.users directly, so remove them explicitly.
  delete from public.interview_sessions where user_id = p_user_id;

  -- User-owned rows reference profiles with ON DELETE CASCADE. Match history is
  -- retained only as anonymized aggregate history through ON DELETE SET NULL.
  delete from public.profiles where id = p_user_id;

  insert into public.profiles (id, username, full_name, target, created_at)
  values (p_user_id, v_username, v_full_name, v_target, v_created_at);
end;
$$;

revoke all on function public.reset_user_account_data(uuid) from public;
revoke all on function public.reset_user_account_data(uuid) from anon;
revoke all on function public.reset_user_account_data(uuid) from authenticated;
grant execute on function public.reset_user_account_data(uuid) to service_role;
