-- Align operational Solo Standard sessions with the canonical Learning V2 ledger.

begin;

alter table public.solo_sessions
  add column if not exists requested_mechanic_mode text,
  add column if not exists effective_mechanic_mode text,
  add column if not exists question_selection_type text,
  add column if not exists recommendation_id uuid references public.learning_recommendations(id) on delete set null,
  add column if not exists learning_objective text,
  add column if not exists policy_stop_trigger text;

alter table public.solo_sessions
  drop constraint if exists solo_sessions_completion_reason_check,
  drop constraint if exists solo_sessions_policy_stop_trigger_check;

update public.solo_sessions
set requested_mechanic_mode = coalesce(requested_mechanic_mode, mechanic_mode),
    effective_mechanic_mode = coalesce(effective_mechanic_mode, mechanic_mode),
    question_selection_type = coalesce(question_selection_type, question_selection),
    policy_stop_trigger = case
      when completion_reason in ('tower_destroyed', 'questions_completed')
        then completion_reason
      else policy_stop_trigger
    end,
    completion_reason = case
      when completion_reason in ('tower_destroyed', 'questions_completed')
        then 'policy_completed'
      else completion_reason
    end;

alter table public.solo_sessions
  alter column requested_mechanic_mode set default 'standard',
  alter column requested_mechanic_mode set not null,
  alter column effective_mechanic_mode set default 'standard',
  alter column effective_mechanic_mode set not null,
  alter column question_selection_type set default 'balanced',
  alter column question_selection_type set not null;

alter table public.solo_sessions
  add constraint solo_sessions_completion_reason_check check (
    completion_reason is null or completion_reason in ('policy_completed', 'user_stopped')
  ),
  add constraint solo_sessions_policy_stop_trigger_check check (
    policy_stop_trigger is null or policy_stop_trigger in ('tower_destroyed', 'questions_completed')
  );

alter table public.solo_session_questions
  add column if not exists question_revision_id uuid references public.question_revisions(id) on delete restrict,
  add column if not exists taxonomy_version_id uuid,
  add column if not exists skill_id text,
  add column if not exists exposure_count_before integer,
  add column if not exists seen_before boolean,
  add column if not exists hint_requested_at timestamptz,
  add column if not exists hint_idempotency_key text;

alter table public.solo_session_questions
  drop constraint if exists solo_session_questions_skill_fkey,
  add constraint solo_session_questions_skill_fkey
    foreign key (taxonomy_version_id, skill_id)
    references public.learning_skills(taxonomy_version_id, skill_id)
    on delete restrict;

alter table public.solo_answers
  add column if not exists canonical_attempt_id uuid references public.learning_attempts(id) on delete restrict,
  add column if not exists client_active_response_time_ms integer,
  add column if not exists background_duration_ms integer,
  add column if not exists effective_response_time_ms integer;

create unique index if not exists solo_answers_canonical_attempt_unique_idx
  on public.solo_answers(canonical_attempt_id)
  where canonical_attempt_id is not null;

create or replace function public.solo_session_payload(p_user_id uuid, p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.solo_sessions%rowtype;
  v_hand jsonb;
begin
  select * into v_session from public.solo_sessions
  where id = p_session_id and user_id = p_user_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo session';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'sessionQuestionId', available.id,
    'questionOrder', available.question_order,
    'category', available.category,
    'subcategory', available.subcategory,
    'openedAt', available.opened_at,
    'deadlineAt', available.deadline_at
  ) order by available.question_order), '[]'::jsonb)
  into v_hand
  from (
    select sq.id, sq.question_order, q.category, q.subcategory,
      sq.opened_at, sq.deadline_at
    from public.solo_session_questions sq
    join public.questions q on q.id = sq.question_id
    where sq.session_id = p_session_id and sq.resolved_at is null
    order by sq.question_order
    limit 3
  ) available;

  return jsonb_build_object(
    'sessionId', v_session.id,
    'target', v_session.target,
    'mechanicMode', v_session.effective_mechanic_mode,
    'requestedMechanicMode', v_session.requested_mechanic_mode,
    'effectiveMechanicMode', v_session.effective_mechanic_mode,
    'questionSelection', v_session.question_selection_type,
    'questionCount', v_session.question_count,
    'characterId', v_session.character_id,
    'status', v_session.status,
    'completionReason', v_session.completion_reason,
    'policyStopTrigger', v_session.policy_stop_trigger,
    'answeredCount', v_session.answered_count,
    'correctCount', v_session.correct_count,
    'towerHp', v_session.tower_hp,
    'rewardCoins', v_session.reward_coins,
    'startedAt', v_session.started_at,
    'finishedAt', v_session.finished_at,
    'hand', v_hand
  );
end;
$$;

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

  if v_sq.opened_at is null then
    v_sq.opened_at := v_now;
    v_sq.deadline_at := v_now + make_interval(
      secs => greatest(coalesce(v_revision.standard_time_limit_ms / 1000, v_question.time_limit_seconds), 1)
    );
    update public.solo_session_questions
    set opened_at = v_sq.opened_at, deadline_at = v_sq.deadline_at
    where id = v_sq.id;
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
    'timeLimitSeconds', greatest(coalesce(v_revision.standard_time_limit_ms / 1000, v_question.time_limit_seconds), 1),
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

create or replace function public.request_solo_hint(
  p_user_id uuid,
  p_session_id uuid,
  p_session_question_id uuid,
  p_idempotency_key text,
  p_requested_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.solo_sessions%rowtype;
  v_sq public.solo_session_questions%rowtype;
  v_hint text;
  v_requested_at timestamptz;
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object(
    'sessionId', p_session_id, 'sessionQuestionId', p_session_question_id
  )::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':solo.hint:' || p_idempotency_key, 0
  ));
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'solo.hint'
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
  if v_sq.opened_at is null or v_sq.question_revision_id is null then
    raise exception using errcode = 'P0001', message = 'CONFLICT: solo question is not open';
  end if;
  if v_sq.deadline_at is not null and p_requested_at >= v_sq.deadline_at then
    raise exception using errcode = 'P0001', message = 'CONFLICT: solo question deadline elapsed';
  end if;
  select hint into v_hint from public.question_revisions
  where id = v_sq.question_revision_id;
  if nullif(btrim(v_hint), '') is null then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: hint is unavailable';
  end if;

  v_requested_at := coalesce(v_sq.hint_requested_at, p_requested_at);
  if v_sq.hint_requested_at is null then
    update public.solo_session_questions
    set hint_requested_at = v_requested_at,
        hint_idempotency_key = p_idempotency_key
    where id = v_sq.id;
  end if;
  v_response := jsonb_build_object(
    'sessionId', p_session_id,
    'sessionQuestionId', p_session_question_id,
    'hint', v_hint,
    'requestedAt', v_requested_at,
    'hintRequestedAt', v_requested_at
  );
  insert into public.api_idempotency_records(
    user_id, operation, idempotency_key, request_hash, response
  ) values (p_user_id, 'solo.hint', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

drop function if exists public.submit_solo_answer(uuid, uuid, text, uuid, integer, boolean, timestamptz);
drop function if exists public.submit_solo_answer(uuid, uuid, text, uuid, integer, timestamptz);
create or replace function public.submit_solo_answer(
  p_user_id uuid,
  p_session_id uuid,
  p_idempotency_key text,
  p_session_question_id uuid,
  p_selected_option_index integer default null,
  p_client_active_response_time_ms integer default null,
  p_background_duration_ms integer default null,
  p_answered_at timestamptz default clock_timestamp()
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
  v_answer public.solo_answers%rowtype;
  v_attempt_id uuid;
  v_hash text;
  v_payload_hash text;
  v_classifier_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_timed_out boolean;
  v_is_correct boolean;
  v_hinted boolean;
  v_invalidated boolean;
  v_answered integer;
  v_correct integer;
  v_hp integer;
  v_trigger text;
  v_requested_reward integer := 0;
  v_reward integer := 0;
  v_earned_today integer := 0;
  v_balance integer;
  v_server_elapsed_ms integer;
  v_effective_ms integer;
  v_timing_invalidity text;
  v_completion_state text;
  v_response jsonb;
  v_exclusions text[] := '{}';
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  if p_client_active_response_time_ms is not null and p_client_active_response_time_ms < 0 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: clientActiveResponseTimeMs';
  end if;
  if p_background_duration_ms is not null and p_background_duration_ms < 0 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: backgroundDurationMs';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object(
    'sessionId', p_session_id,
    'sessionQuestionId', p_session_question_id,
    'selectedOptionIndex', p_selected_option_index,
    'clientActiveResponseTimeMs', p_client_active_response_time_ms,
    'backgroundDurationMs', p_background_duration_ms
  )::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':solo.answer:' || p_idempotency_key, 0
  ));
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'solo.answer'
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
  select * into v_sq from public.solo_session_questions
  where id = p_session_question_id and session_id = p_session_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo question'; end if;

  if v_sq.resolved_at is not null then
    select * into v_answer from public.solo_answers
    where session_question_id = v_sq.id;
    if not found then raise exception using errcode = 'P0001', message = 'CONFLICT: solo question resolution is incomplete'; end if;
    v_response := public.solo_session_payload(p_user_id, p_session_id) || jsonb_build_object(
      'attemptId', v_answer.canonical_attempt_id,
      'answerResult', jsonb_build_object(
        'sessionQuestionId', v_sq.id,
        'attemptId', v_answer.canonical_attempt_id,
        'isCorrect', v_answer.is_correct,
        'timedOut', v_answer.timed_out,
        'correctOptionIndex', v_answer.correct_option_index_snapshot,
        'explanation', v_answer.explanation_snapshot
      )
    );
    insert into public.api_idempotency_records(
      user_id, operation, idempotency_key, request_hash, response
    ) values (p_user_id, 'solo.answer', p_idempotency_key, v_hash, v_response);
    return v_response;
  end if;

  if v_session.status <> 'active' then
    raise exception using errcode = 'P0001', message = 'CONFLICT: solo session finished';
  end if;
  if v_sq.opened_at is null or v_sq.deadline_at is null or v_sq.question_revision_id is null then
    raise exception using errcode = 'P0001', message = 'CONFLICT: solo question is not open';
  end if;
  select * into v_question from public.questions where id = v_sq.question_id;
  select * into v_revision from public.question_revisions where id = v_sq.question_revision_id;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: question revision'; end if;

  v_timed_out := p_answered_at >= v_sq.deadline_at;
  if not v_timed_out and (p_selected_option_index is null
      or p_selected_option_index < 0
      or p_selected_option_index >= jsonb_array_length(v_revision.options)) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: selectedOptionIndex';
  end if;
  v_is_correct := not v_timed_out
    and p_selected_option_index = v_revision.correct_option_index;
  v_hinted := v_sq.hint_requested_at is not null;
  v_server_elapsed_ms := greatest(0, floor(extract(epoch from (
    least(p_answered_at, v_sq.deadline_at) - v_sq.opened_at
  )) * 1000)::integer);
  if p_client_active_response_time_ms is null then
    v_timing_invalidity := 'client_active_time_missing';
    v_effective_ms := null;
  elsif p_client_active_response_time_ms > v_server_elapsed_ms + 2000 then
    v_timing_invalidity := 'client_active_time_exceeds_server_elapsed';
    v_effective_ms := null;
  elsif p_background_duration_ms is not null
      and p_client_active_response_time_ms + p_background_duration_ms > v_server_elapsed_ms + 2000 then
    v_timing_invalidity := 'client_timing_components_exceed_server_elapsed';
    v_effective_ms := null;
  else
    v_effective_ms := p_client_active_response_time_ms;
  end if;

  insert into public.solo_answers(
    session_id, session_question_id, user_id, question_id,
    selected_option_index, is_correct, timed_out, used_hint,
    response_time_ms, client_active_response_time_ms,
    background_duration_ms, effective_response_time_ms,
    correct_option_index_snapshot, explanation_snapshot, answered_at
  ) values (
    p_session_id, v_sq.id, p_user_id, v_question.id,
    case when v_timed_out then null else p_selected_option_index end,
    v_is_correct, v_timed_out, v_hinted, v_server_elapsed_ms,
    p_client_active_response_time_ms, p_background_duration_ms, v_effective_ms,
    v_revision.correct_option_index, v_revision.explanation, p_answered_at
  ) returning * into v_answer;
  update public.solo_session_questions
  set resolved_at = p_answered_at where id = v_sq.id;

  select count(*), count(*) filter (where is_correct)
  into v_answered, v_correct
  from public.solo_answers where session_id = p_session_id;
  v_hp := ceil(100.0 * (v_session.question_count - v_correct)
    / v_session.question_count)::integer;
  v_completion_state := case
    when v_answered = v_session.question_count then 'policy_completed'
    else 'in_progress'
  end;
  update public.solo_sessions
  set answered_count = v_answered,
      correct_count = v_correct,
      tower_hp = v_hp,
      updated_at = p_answered_at
  where id = p_session_id;

  if v_answered = v_session.question_count then
    v_trigger := case
      when v_correct = v_session.question_count then 'tower_destroyed'
      else 'questions_completed'
    end;
    v_requested_reward := case when v_trigger = 'tower_destroyed' then 10 else 3 end;
    select coalesce(sum(delta), 0) into v_earned_today
    from public.coin_transactions
    where user_id = p_user_id and reason = 'solo_reward'
      and public.wib_business_date(created_at) = public.wib_business_date(p_answered_at);
    v_reward := least(v_requested_reward, greatest(30 - v_earned_today, 0));
    if v_reward > 0 then
      update public.profiles
      set coins = coins + v_reward, updated_at = p_answered_at
      where id = p_user_id returning coins into v_balance;
      insert into public.coin_transactions(
        user_id, delta, reason, reference_id, idempotency_key, balance_after
      ) values (
        p_user_id, v_reward, 'solo_reward', p_session_id::text,
        'solo:' || p_session_id, v_balance
      ) on conflict (user_id, idempotency_key) do nothing;
    end if;
    update public.solo_sessions
    set status = 'completed',
        completion_reason = 'policy_completed',
        policy_stop_trigger = v_trigger,
        reward_coins = v_reward,
        finished_at = p_answered_at,
        updated_at = p_answered_at
    where id = p_session_id;
  end if;

  v_payload_hash := encode(extensions.digest(jsonb_build_object(
    'soloAnswerId', v_answer.id,
    'questionRevisionId', v_revision.id,
    'selectedOptionIndex', v_answer.selected_option_index,
    'isCorrect', v_answer.is_correct,
    'timedOut', v_answer.timed_out,
    'hintRequested', v_hinted,
    'seenBefore', v_sq.seen_before,
    'answeredAt', v_answer.answered_at
  )::text, 'sha256'), 'hex');
  insert into public.learning_attempts(
    source, source_attempt_key, source_payload_hash, data_fidelity,
    user_id, target, source_session_key, recommendation_id,
    learning_objective, requested_mechanic_mode, effective_mechanic_mode,
    question_selection_type, delivery_policy_id, session_completion_state,
    question_id, question_revision_id, taxonomy_version_id, skill_id,
    content_version, category, subcategory, difficulty, expected_time_ms,
    standard_time_limit_ms, curriculum_weight, question_quality_state,
    selected_option_index, is_correct, hint_requested, timed_out,
    first_attempt, seen_before, exposure_count_before, explanation_viewed,
    opened_at, answered_at, deadline_at, client_active_response_time_ms,
    server_elapsed_time_ms, background_duration_ms,
    effective_response_time_ms, timing_invalidity_reason, source_event_at
  ) values (
    'solo', 'solo:' || v_answer.id::text, v_payload_hash, 'v2_complete',
    p_user_id, v_session.target, p_session_id::text, v_session.recommendation_id,
    v_session.learning_objective, v_session.requested_mechanic_mode,
    v_session.effective_mechanic_mode, v_session.question_selection_type,
    v_session.policy_id || ':v' || v_session.policy_version,
    v_completion_state, v_question.id, v_revision.id,
    v_sq.taxonomy_version_id, v_sq.skill_id, v_revision.content_version,
    v_revision.category, v_revision.subcategory, v_revision.difficulty,
    v_revision.expected_time_ms, v_revision.standard_time_limit_ms,
    v_revision.curriculum_weight, v_revision.quality_state,
    v_answer.selected_option_index, v_answer.is_correct, v_hinted,
    v_answer.timed_out, true, v_sq.seen_before, v_sq.exposure_count_before,
    false, v_sq.opened_at, v_answer.answered_at, v_sq.deadline_at,
    p_client_active_response_time_ms, v_server_elapsed_ms,
    p_background_duration_ms, v_effective_ms, v_timing_invalidity,
    v_answer.answered_at
  ) returning id into v_attempt_id;

  v_invalidated := exists (
    select 1 from public.learning_attempt_invalidations invalidation
    where invalidation.question_revision_id = v_revision.id
  );
  if v_invalidated then v_exclusions := array_append(v_exclusions, 'revision_invalidated'); end if;
  if v_hinted then v_exclusions := array_append(v_exclusions, 'hint_assisted'); end if;
  if coalesce(v_sq.seen_before, false) then v_exclusions := array_append(v_exclusions, 'previously_exposed'); end if;
  if v_timed_out then v_exclusions := array_append(v_exclusions, 'timed_out'); end if;
  if v_timing_invalidity is not null then v_exclusions := array_append(v_exclusions, v_timing_invalidity); end if;
  v_classifier_hash := encode(extensions.digest(jsonb_build_object(
    'attemptId', v_attempt_id,
    'classificationVersion', 'evidence-v1',
    'hintRequested', v_hinted,
    'seenBefore', v_sq.seen_before,
    'timedOut', v_timed_out,
    'timingInvalidityReason', v_timing_invalidity
  )::text, 'sha256'), 'hex');
  insert into public.learning_attempt_classifications(
    attempt_id, classification_version, classifier_input_hash,
    valid_for_activity_accuracy, valid_for_independent_accuracy,
    valid_for_unseen_independent_accuracy, valid_for_assisted_accuracy,
    valid_for_pace_analytics, valid_for_fluency_baseline,
    valid_for_retention, exclusion_reasons, classified_at
  ) values (
    v_attempt_id, 'evidence-v1', v_classifier_hash,
    not v_invalidated,
    not v_invalidated and not v_hinted,
    not v_invalidated and not v_hinted and not coalesce(v_sq.seen_before, false),
    not v_invalidated and v_hinted,
    not v_invalidated and not v_hinted and not v_timed_out and v_timing_invalidity is null,
    not v_invalidated and not v_hinted and not v_timed_out and v_timing_invalidity is null,
    not v_invalidated and not v_hinted and not coalesce(v_sq.seen_before, false),
    v_exclusions, p_answered_at
  );
  update public.solo_answers
  set canonical_attempt_id = v_attempt_id
  where id = v_answer.id;

  v_response := public.solo_session_payload(p_user_id, p_session_id) || jsonb_build_object(
    'attemptId', v_attempt_id,
    'answerResult', jsonb_build_object(
      'sessionQuestionId', v_sq.id,
      'attemptId', v_attempt_id,
      'isCorrect', v_is_correct,
      'timedOut', v_timed_out,
      'correctOptionIndex', v_revision.correct_option_index,
      'explanation', v_revision.explanation,
      'timing', jsonb_build_object(
        'clientActiveMs', p_client_active_response_time_ms,
        'serverElapsedMs', v_server_elapsed_ms,
        'backgroundMs', p_background_duration_ms,
        'effectiveMs', v_effective_ms,
        'invalidityReason', v_timing_invalidity
      ),
      'evidence', jsonb_build_object('hintRequested', v_hinted)
    )
  );
  insert into public.api_idempotency_records(
    user_id, operation, idempotency_key, request_hash, response
  ) values (p_user_id, 'solo.answer', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

create or replace function public.reconcile_solo_session(
  p_user_id uuid,
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expired record;
begin
  for v_expired in
    select sq.id, sq.deadline_at
    from public.solo_session_questions sq
    join public.solo_sessions session on session.id = sq.session_id
    where sq.session_id = p_session_id
      and session.user_id = p_user_id
      and session.status = 'active'
      and sq.resolved_at is null
      and sq.deadline_at is not null
      and sq.deadline_at <= clock_timestamp()
    order by sq.deadline_at, sq.question_order
  loop
    perform public.submit_solo_answer(
      p_user_id,
      p_session_id,
      'timeout:' || v_expired.id::text,
      v_expired.id,
      null,
      null,
      null,
      greatest(v_expired.deadline_at, clock_timestamp())
    );
  end loop;
  return public.solo_session_payload(p_user_id, p_session_id);
end;
$$;

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
    -- Legacy sessions must first reopen a card so its canonical revision can be
    -- snapshotted before authoritative timeout reconciliation can submit it.
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

revoke all on function public.request_solo_hint(uuid, uuid, uuid, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, integer, integer, timestamptz)
  from public, anon, authenticated;
revoke all on function public.reconcile_solo_session(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.request_solo_hint(uuid, uuid, uuid, text, timestamptz)
  to service_role;
grant execute on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, integer, integer, timestamptz)
  to service_role;
grant execute on function public.reconcile_solo_session(uuid, uuid)
  to service_role;

commit;

notify pgrst, 'reload schema';
