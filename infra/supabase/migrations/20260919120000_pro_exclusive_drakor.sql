begin;

-- Change acquisition rules only; existing inventory and equipped skins survive.
update public.store_items
set is_pro_exclusive = (id = 'character-legend-drakor')
where id in ('character-basic-pip', 'character-legend-drakor');

update public.economy_policy_versions
set policy = jsonb_set(policy, '{pro,exclusiveSkinIds}', (
  select jsonb_agg(
    case when skin.id = 'character-basic-pip' then 'character-legend-drakor'
      else skin.id end order by skin.position
  )
  from jsonb_array_elements_text(policy #> '{pro,exclusiveSkinIds}')
    with ordinality as skin(id, position)
))
where (policy #> '{pro,exclusiveSkinIds}') ? 'character-basic-pip';

commit;
