begin;

-- Keep the authoritative policy aligned with the recharge packages displayed
-- by the mobile client. purchase_energy_pack reads this JSON at runtime.
update public.economy_policy_versions
set policy = jsonb_set(
  policy,
  '{energy,packs}',
  '[
    {"id":"energy-5","energy":5,"yCoinCost":50},
    {"id":"energy-12","energy":12,"yCoinCost":100}
  ]'::jsonb
)
where is_active;

commit;
