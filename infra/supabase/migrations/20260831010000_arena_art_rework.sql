update public.store_items
set
  name = case id
    when 'character-basic-squire' then 'Ody'
    when 'character-basic-pip' then 'Opy'
    else name
  end,
  description = case id
    when 'character-basic-squire'
      then 'Ksatria muda yang tangguh dan selalu siap berlatih.'
    when 'tower-benteng-bara'
      then 'Menara batu hitam yang diperkuat aliran magma.'
    else description
  end,
  updated_at = now()
where id in (
  'character-basic-squire',
  'character-basic-pip',
  'tower-benteng-bara'
);

insert into public.store_items (
  id,
  type,
  name,
  description,
  rarity,
  coin_price,
  is_active,
  is_pass_exclusive
)
values
  (
    'arena-lembah-bara',
    'arena',
    'Lembah Bara',
    'Lembah hijau yang berhadapan langsung dengan kawah api.',
    'common',
    0,
    true,
    false
  ),
  (
    'arena-padang-harmoni',
    'arena',
    'Padang Harmoni',
    'Padang bunga cerah untuk duel yang tenang dan sportif.',
    'common',
    0,
    true,
    false
  ),
  (
    'arena-gurun-cendekia',
    'arena',
    'Gurun Cendekia',
    'Arena tandus terbuka untuk adu strategi tanpa gangguan.',
    'common',
    0,
    true,
    false
  ),
  (
    'arena-rimba-yudha',
    'arena',
    'Rimba Yudha',
    'Rimba teduh dengan cahaya alami di tengah medan duel.',
    'common',
    0,
    true,
    false
  )
on conflict (id) do update set
  type = excluded.type,
  name = excluded.name,
  description = excluded.description,
  rarity = excluded.rarity,
  coin_price = excluded.coin_price,
  is_active = excluded.is_active,
  is_pass_exclusive = excluded.is_pass_exclusive,
  updated_at = now();

update public.store_items
set is_active = false, updated_at = now()
where id in ('arena-cpns', 'arena-bumn');

insert into public.user_inventory (user_id, item_id, source, source_ref)
select
  profile.id,
  arena.id,
  'admin',
  'arena-art-rework-2026-08'
from public.profiles profile
cross join public.store_items arena
where arena.type = 'arena'
  and arena.coin_price = 0
  and arena.is_active
on conflict (user_id, item_id) do nothing;

update public.profiles
set equipped_arena_id = 'arena-padang-harmoni', updated_at = now()
where equipped_arena_id is null
  or equipped_arena_id in ('arena-cpns', 'arena-bumn')
  or not exists (
    select 1
    from public.store_items arena
    where arena.id = profiles.equipped_arena_id
      and arena.type = 'arena'
      and arena.is_active
  );

alter table public.profiles
  alter column equipped_arena_id set default 'arena-padang-harmoni';

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
    'arena-padang-harmoni',
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
