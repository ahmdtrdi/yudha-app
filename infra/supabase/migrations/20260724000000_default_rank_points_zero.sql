-- New profiles should start unranked. Existing profile balances are unchanged.
alter table public.profiles
alter column rank_points set default 0;
