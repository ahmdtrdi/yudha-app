-- Returns no rows when active Solo recovery remains backend-only and callable.

select 'get_active_solo_session is missing' as issue
where to_regprocedure('public.get_active_solo_session(uuid)') is null
union all
select 'authenticated can execute active Solo recovery directly' as issue
where has_function_privilege(
  'authenticated',
  'public.get_active_solo_session(uuid)',
  'EXECUTE'
)
union all
select 'service_role cannot execute active Solo recovery' as issue
where not has_function_privilege(
  'service_role',
  'public.get_active_solo_session(uuid)',
  'EXECUTE'
);
