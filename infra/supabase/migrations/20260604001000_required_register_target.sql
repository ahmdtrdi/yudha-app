alter table public.profiles
drop constraint if exists profiles_target_check;

alter table public.profiles
add constraint profiles_target_check
check (target in ('cpns', 'bumn', 'kedinasan'));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, full_name, target)
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
    new.raw_user_meta_data ->> 'target'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
