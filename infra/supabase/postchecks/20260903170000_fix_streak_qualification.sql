do $$
begin
  if exists (
    select 1
    from public.daily_learning_activity
    where source_type not in ('solo', 'ranked', 'casual')
  ) then
    raise exception 'Non-qualifying activity exists in the streak ledger.';
  end if;

  if exists (
    select 1
    from public.profiles profile
    where profile.current_streak > 0
      and not exists (
        select 1
        from public.daily_learning_activity activity
        where activity.user_id = profile.id
      )
  ) then
    raise exception 'A profile has a streak without qualifying activity.';
  end if;

  if exists (
    select 1
    from public.profiles profile
    where profile.current_streak = 0
      and profile.last_streak_date is not null
  ) then
    raise exception 'A zero-streak profile still has a streak date.';
  end if;
end;
$$;
