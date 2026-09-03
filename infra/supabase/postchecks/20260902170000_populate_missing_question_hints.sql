select
  not exists (
    select 1
    from public.questions
    where is_active = true
      and target in ('cpns', 'bumn')
      and (hint is null or trim(hint) = '')
  ) as passed,
  'Every active CPNS and BUMN question has a non-empty hint.' as check_name;
