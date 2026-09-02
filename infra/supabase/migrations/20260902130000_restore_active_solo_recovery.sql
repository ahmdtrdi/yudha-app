-- Keep active Solo sessions discoverable while legacy cards gain V2 snapshots.

begin;

create or replace function public.get_active_solo_session(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session_id uuid;
  v_payload jsonb;
begin
  select id into v_session_id from public.solo_sessions
  where user_id = p_user_id and status = 'active'
  order by started_at desc limit 1;
  if v_session_id is null then
    return jsonb_build_object('activeSession', null);
  end if;

  if exists (
    select 1 from public.solo_session_questions question
    where question.session_id = v_session_id
      and question.resolved_at is null
      and question.deadline_at is not null
      and question.deadline_at <= clock_timestamp()
      and question.question_revision_id is null
  ) then
    -- Reopening a legacy card snapshots its canonical revision. Until then,
    -- return it for explicit resume/end instead of hiding it behind an error.
    v_payload := public.solo_session_payload(p_user_id, v_session_id);
  else
    v_payload := public.reconcile_solo_session(p_user_id, v_session_id);
  end if;

  if v_payload ->> 'status' <> 'active' then
    return jsonb_build_object('activeSession', null);
  end if;
  return jsonb_build_object('activeSession', v_payload);
end;
$$;

revoke all on function public.get_active_solo_session(uuid)
  from public, anon, authenticated;
grant execute on function public.get_active_solo_session(uuid)
  to service_role;

commit;

notify pgrst, 'reload schema';
