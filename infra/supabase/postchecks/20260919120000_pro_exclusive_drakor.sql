select 'opy_purchasable' as check_name, exists (
  select 1 from public.store_items
  where id = 'character-basic-pip' and is_active and not is_pro_exclusive
    and coin_price = 500
) as passed
union all
select 'drakor_exclusive', exists (
  select 1 from public.store_items
  where id = 'character-legend-drakor' and is_active and is_pro_exclusive
)
union all
select 'policy_matches_store', exists (
  select 1 from public.economy_policy_versions where is_active
) and not exists (
  select 1 from public.store_items item
  cross join public.economy_policy_versions policy
  where policy.is_active and item.is_active
    and item.is_pro_exclusive is distinct from
      ((policy.policy #> '{pro,exclusiveSkinIds}') ? item.id)
);
