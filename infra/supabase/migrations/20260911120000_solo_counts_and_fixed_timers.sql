-- New sessions offer 10/20/30 questions. Retain historical 35/50-question sessions.
begin;

alter table public.solo_sessions
  drop constraint if exists solo_sessions_question_count_check;
alter table public.solo_sessions
  add constraint solo_sessions_question_count_check
    check (question_count in (10, 20, 30, 35, 50));

create or replace function public.create_solo_session(
  p_user_id uuid,
  p_idempotency_key text,
  p_mechanic_mode text,
  p_question_selection text,
  p_question_count integer,
  p_character_id text,
  p_recommendation_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target text;
  v_session_id uuid;
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_selected_count integer;
  v_rec_skill_ids text[];
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  if p_mechanic_mode not in ('focus', 'standard', 'speed') or p_question_selection not in ('balanced', 'recommended') then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: invalid mechanic mode or question selection';
  end if;
  if p_question_count not in (10, 20, 30) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: questionCount';
  end if;
  if p_character_id is null or btrim(p_character_id) = '' then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: characterId';
  end if;

  v_hash := encode(extensions.digest(jsonb_build_object(
    'mechanicMode', p_mechanic_mode, 'questionSelection', p_question_selection,
    'questionCount', p_question_count, 'characterId', p_character_id,
    'recommendationId', p_recommendation_id
  )::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':solo.create:' || p_idempotency_key, 0));
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'solo.create' and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_record.response;
  end if;

  select target into v_target from public.profiles where id = p_user_id;
  if v_target not in ('cpns', 'bumn') then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile target';
  end if;
  if not exists (
    select 1 from public.user_inventory inventory
    join public.store_items item on item.id = inventory.item_id
    where inventory.user_id = p_user_id and item.id = btrim(p_character_id)
      and item.type = 'character_skin' and item.is_active
  ) then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: character is not owned or available';
  end if;
  if exists (select 1 from public.solo_sessions where user_id = p_user_id and status = 'active') then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: resume the active Solo session first';
  end if;

  insert into public.solo_sessions
    (user_id, target, mechanic_mode, question_selection, question_count, character_id,
     requested_mechanic_mode, effective_mechanic_mode, question_selection_type, recommendation_id)
  values
    (p_user_id, v_target, p_mechanic_mode, p_question_selection, p_question_count, btrim(p_character_id),
     p_mechanic_mode, p_mechanic_mode, p_question_selection, p_recommendation_id)
  returning id into v_session_id;

  if p_question_selection = 'recommended' and p_recommendation_id is not null then
    select skill_ids into v_rec_skill_ids
    from public.learning_recommendations
    where id = p_recommendation_id;
  end if;

  if v_rec_skill_ids is not null and cardinality(v_rec_skill_ids) > 0 then
    with candidates as (
      select q.id
      from public.questions q
      join public.question_revisions qr on qr.question_id = q.id and qr.is_active
      join public.question_skill_mappings qsm on qsm.question_revision_id = qr.id
      where qsm.skill_id = any(v_rec_skill_ids)
        and q.target = v_target
        and q.is_active
      group by q.id
    ), recommended_pool as (
      select id
      from candidates
      order by random()
      limit p_question_count
    ), fill_pool as (
      select q.id
      from public.questions q
      where q.target = v_target
        and q.is_active
        and q.id not in (select id from recommended_pool)
      order by random()
      limit greatest(p_question_count - (select count(*) from recommended_pool), 0)
    ), selected as (
      select id from recommended_pool union all select id from fill_pool
    )
    insert into public.solo_session_questions(session_id, question_id, question_order)
    select v_session_id, id, row_number() over (order by random())::integer from selected;
  else
    with policy as (
      select * from (values
        ('cpns'::text, 'twk'::text, 6::integer, 1::integer),
        ('cpns', 'tiu', 7, 2),
        ('bumn', 'tkd', 3, 1),
        ('bumn', 'akhlak', 1, 2)
      ) value(target, category, weight, priority)
      where target = v_target
    ), weighted as (
      select *, p_question_count * weight::numeric / sum(weight) over () as exact_count
      from policy
    ), quotas as (
      select *, floor(exact_count)::integer
        + case when row_number() over (order by exact_count - floor(exact_count) desc, priority)
            <= p_question_count - sum(floor(exact_count)::integer) over () then 1 else 0 end as quota
      from weighted
    ), initially_selected as (
      select candidate.id
      from quotas quota
      cross join lateral (
        select q.id from public.questions q
        where q.target = v_target and q.is_active and lower(q.category) = quota.category
        order by random()
        limit quota.quota
      ) candidate
    ), fill_selected as (
      select q.id from public.questions q
      where q.target = v_target and q.is_active
        and lower(q.category) in (select category from policy)
        and q.id not in (select id from initially_selected)
      order by random()
      limit greatest(p_question_count - (select count(*) from initially_selected), 0)
    ), selected as (
      select id from initially_selected union all select id from fill_selected
    )
    insert into public.solo_session_questions(session_id, question_id, question_order)
    select v_session_id, id, row_number() over (order by random())::integer from selected;
  end if;

  select count(*) into v_selected_count from public.solo_session_questions where session_id = v_session_id;
  if v_selected_count <> p_question_count then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: insufficient unique question inventory';
  end if;

  v_response := public.solo_session_payload(p_user_id, v_session_id);
  insert into public.api_idempotency_records(user_id, operation, idempotency_key, request_hash, response)
  values (p_user_id, 'solo.create', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

revoke all on function public.create_solo_session(uuid, text, text, text, integer, text, uuid) from public, anon, authenticated;
grant execute on function public.create_solo_session(uuid, text, text, text, integer, text, uuid) to service_role;

create or replace function public.open_solo_question(
  p_user_id uuid,
  p_session_id uuid,
  p_session_question_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.solo_sessions%rowtype;
  v_sq public.solo_session_questions%rowtype;
  v_question public.questions%rowtype;
  v_revision public.question_revisions%rowtype;
  v_revision_id uuid;
  v_taxonomy_version_id uuid;
  v_skill_id text;
  v_exposure_count integer;
  v_available_rank integer;
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
  v_effective_time_sec integer;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object(
    'sessionId', p_session_id, 'sessionQuestionId', p_session_question_id
  )::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':solo.open:' || p_idempotency_key, 0
  ));
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'solo.open'
    and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_record.response;
  end if;

  select * into v_session from public.solo_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo session'; end if;
  if v_session.status <> 'active' then
    raise exception using errcode = 'P0001', message = 'CONFLICT: solo session finished';
  end if;

  select * into v_sq from public.solo_session_questions
  where id = p_session_question_id and session_id = p_session_id for update;
  if not found or v_sq.resolved_at is not null then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo question';
  end if;
  select count(*) into v_available_rank
  from public.solo_session_questions sq
  where sq.session_id = p_session_id and sq.resolved_at is null
    and sq.question_order <= v_sq.question_order;
  if v_available_rank > 3 then
    raise exception using errcode = 'P0001', message = 'CONFLICT: question is outside the current hand';
  end if;
  select * into v_question from public.questions where id = v_sq.question_id;

  if v_sq.question_revision_id is null then
    select revision.id, mapping.taxonomy_version_id, mapping.skill_id
    into v_revision_id, v_taxonomy_version_id, v_skill_id
    from public.question_revisions revision
    join public.question_skill_mappings mapping
      on mapping.question_revision_id = revision.id
     and mapping.mapping_type = 'primary'
    join public.learning_taxonomy_versions taxonomy
      on taxonomy.id = mapping.taxonomy_version_id
     and taxonomy.effective_at <= v_now
    join public.learning_skills skill
      on skill.taxonomy_version_id = mapping.taxonomy_version_id
     and skill.skill_id = mapping.skill_id
     and skill.target = v_session.target
     and skill.enabled
    where revision.question_id = v_sq.question_id
      and revision.is_active
      and revision.quality_state not in ('invalidated', 'disabled')
    order by taxonomy.effective_at desc, revision.revision desc, revision.created_at desc
    limit 1;
    if v_revision_id is null or v_skill_id is null then
      raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: question lacks a current Learning V2 revision mapping';
    end if;
    select * into strict v_revision from public.question_revisions
    where id = v_revision_id;

    select exposure_count into v_exposure_count
    from public.learner_question_exposures
    where user_id = p_user_id and question_id = v_sq.question_id
    for update;
    v_exposure_count := coalesce(v_exposure_count, 0);

    update public.solo_session_questions
    set question_revision_id = v_revision.id,
        taxonomy_version_id = v_taxonomy_version_id,
        skill_id = v_skill_id,
        exposure_count_before = v_exposure_count,
        seen_before = v_exposure_count > 0
    where id = v_sq.id;

    insert into public.learner_question_exposures(
      user_id, question_id, exposure_count, first_presented_at,
      last_presented_at, last_source, updated_at
    ) values (
      p_user_id, v_sq.question_id, 1, v_now, v_now, 'solo', v_now
    ) on conflict (user_id, question_id) do update set
      exposure_count = public.learner_question_exposures.exposure_count + 1,
      last_presented_at = excluded.last_presented_at,
      last_source = excluded.last_source,
      updated_at = excluded.updated_at;
  else
    select * into v_revision from public.question_revisions
    where id = v_sq.question_revision_id;
  end if;


  if v_session.effective_mechanic_mode = 'focus' or v_session.mechanic_mode = 'focus' then
    v_effective_time_sec := 0;
  elsif v_session.effective_mechanic_mode = 'speed' or v_session.mechanic_mode = 'speed' then
    v_effective_time_sec := 20;
  else
    v_effective_time_sec := 40;
  end if;

  if v_sq.opened_at is null then
    v_sq.opened_at := v_now;
    if v_session.effective_mechanic_mode = 'focus' or v_session.mechanic_mode = 'focus' then
      v_sq.deadline_at := null;
    else
      v_sq.deadline_at := v_now + make_interval(secs => v_effective_time_sec);
    end if;
    update public.solo_session_questions
    set opened_at = v_sq.opened_at, deadline_at = v_sq.deadline_at
    where id = v_sq.id;
  elsif (v_session.effective_mechanic_mode = 'focus' or v_session.mechanic_mode = 'focus') and v_sq.deadline_at is not null then
    v_sq.deadline_at := null;
    update public.solo_session_questions set deadline_at = null where id = v_sq.id;
  end if;

  v_response := jsonb_build_object(
    'sessionQuestionId', v_sq.id,
    'questionId', v_question.id,
    'questionRevisionId', coalesce(v_sq.question_revision_id, v_revision.id),
    'skillId', coalesce(v_sq.skill_id, v_skill_id),
    'questionOrder', v_sq.question_order,
    'category', v_question.category,
    'subcategory', v_question.subcategory,
    'prompt', v_question.prompt,
    'options', v_question.options,
    'timeLimitSeconds', v_effective_time_sec,
    'hintAvailable', nullif(btrim(v_revision.hint), '') is not null,
    'openedAt', v_sq.opened_at,
    'deadlineAt', v_sq.deadline_at
  );
  insert into public.api_idempotency_records(
    user_id, operation, idempotency_key, request_hash, response
  ) values (p_user_id, 'solo.open', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

revoke all on function public.open_solo_question(uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.open_solo_question(uuid, uuid, uuid, text) to service_role;

commit;
