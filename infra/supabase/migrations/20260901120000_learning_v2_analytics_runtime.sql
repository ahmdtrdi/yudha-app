-- Learning V2 analytics runtime and fixed-five Practice compatibility adapter.
-- Additive and safe to paste into the Supabase Cloud SQL Editor as one unit.

begin;

-- Fixture invalidation is append-only. Removing an audit run must never cascade
-- into deleting its canonical evidence ledger.
alter table public.learning_attempts
  drop constraint if exists learning_attempts_fixture_run_id_fkey;

alter table public.learning_attempts
  add constraint learning_attempts_fixture_run_id_fkey
  foreign key (fixture_run_id)
  references public.learning_fixture_runs(id)
  on delete restrict;

-- A question revision may have one primary mapping in each taxonomy version.
drop index if exists public.question_skill_mappings_one_primary_idx;
create unique index question_skill_mappings_one_primary_idx
  on public.question_skill_mappings(question_revision_id, taxonomy_version_id)
  where mapping_type = 'primary';

alter table public.learner_skill_state
  add column if not exists difficulty_level_count integer not null default 0,
  add column if not exists latest_strong_evidence_at timestamptz;

alter table public.learner_skill_state
  drop constraint if exists learner_skill_state_difficulty_count_check;
alter table public.learner_skill_state
  add constraint learner_skill_state_difficulty_count_check
  check (difficulty_level_count >= 0);

create or replace function public.queue_learning_profile_projection()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.target in ('cpns', 'bumn') then
    perform public.enqueue_learning_projection(
      new.id, new.target, null, null, 'manual_rebuild', null
    );
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_learning_projection_queue on public.profiles;
create trigger profiles_learning_projection_queue
after insert on public.profiles
for each row execute function public.queue_learning_profile_projection();

insert into public.learning_projection_jobs(user_id, target, reason)
select profile.id, profile.target, 'manual_rebuild'
from public.profiles profile
where profile.target in ('cpns', 'bumn')
on conflict do nothing;

create or replace function public.create_practice_session_learning_v2(
  p_user_id uuid,
  p_category text default null,
  p_subcategory text default null,
  p_recommendation_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target text;
  v_category text := nullif(lower(btrim(p_category)), '');
  v_subcategory text := nullif(lower(btrim(p_subcategory)), '');
  v_taxonomy_version_id uuid;
  v_objective text;
  v_mechanic text := 'standard';
  v_selection text := 'balanced';
  v_response jsonb;
  v_session_id uuid;
  v_locked record;
  v_revision_id uuid;
  v_skill_id text;
  v_exposure_count integer;
  v_presented_at timestamptz := clock_timestamp();
  v_questions jsonb;
begin
  select target into v_target from public.profiles where id = p_user_id;
  if v_target is null then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;

  if p_recommendation_id is not null then
    select recommendation.taxonomy_version_id, recommendation.objective,
           recommendation.mechanic_mode, recommendation.question_selection_type,
           skill.category, skill.subcategory
    into v_taxonomy_version_id, v_objective, v_mechanic, v_selection,
         v_category, v_subcategory
    from public.learning_recommendations recommendation
    join public.learning_skills skill
      on skill.taxonomy_version_id = recommendation.taxonomy_version_id
     and skill.skill_id = recommendation.skill_ids[1]
    where recommendation.id = p_recommendation_id
      and recommendation.user_id = p_user_id
      and recommendation.target = v_target
      and recommendation.status = 'active'
      and recommendation.expires_at > v_presented_at
      and recommendation.availability_runnable;
    if not found then
      raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: recommendation is unavailable';
    end if;
  else
    select version.id into v_taxonomy_version_id
    from public.learning_taxonomy_versions version
    where version.effective_at <= v_presented_at
    order by version.effective_at desc, version.created_at desc, version.id
    limit 1;
    if v_taxonomy_version_id is null then
      raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: learning taxonomy is unavailable';
    end if;
  end if;

  v_response := public.create_practice_session(
    p_user_id,
    v_category,
    v_subcategory
  );
  v_session_id := (v_response ->> 'sessionId')::uuid;

  update public.practice_sessions
  set recommendation_id = p_recommendation_id,
      taxonomy_version_id = v_taxonomy_version_id,
      learning_objective = v_objective,
      requested_mechanic_mode = v_mechanic,
      effective_mechanic_mode = v_mechanic,
      question_selection_type = v_selection,
      evidence_capture_version = 'compatibility-practice-v2'
  where id = v_session_id;

  for v_locked in
    select locked.id, locked.question_id
    from public.practice_session_questions locked
    where locked.session_id = v_session_id
    order by locked.question_id
    for update
  loop
    select revision.id, mapping.skill_id
    into v_revision_id, v_skill_id
    from public.question_revisions revision
    join public.question_skill_mappings mapping
      on mapping.question_revision_id = revision.id
     and mapping.taxonomy_version_id = v_taxonomy_version_id
     and mapping.mapping_type = 'primary'
    where revision.question_id = v_locked.question_id
      and revision.is_active
      and revision.quality_state not in ('invalidated', 'disabled')
    order by revision.revision desc, revision.created_at desc
    limit 1;
    if v_revision_id is null or v_skill_id is null then
      raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: selected question lacks a current Learning V2 revision mapping';
    end if;

    select exposure.exposure_count into v_exposure_count
    from public.learner_question_exposures exposure
    where exposure.user_id = p_user_id
      and exposure.question_id = v_locked.question_id
    for update;
    v_exposure_count := coalesce(v_exposure_count, 0);

    update public.practice_session_questions
    set question_revision_id = v_revision_id,
        taxonomy_version_id = v_taxonomy_version_id,
        skill_id = v_skill_id,
        exposure_count_before = v_exposure_count,
        seen_before = v_exposure_count > 0,
        opened_at = v_presented_at
    where id = v_locked.id;

    insert into public.learner_question_exposures(
      user_id, question_id, exposure_count, first_presented_at,
      last_presented_at, last_source, updated_at
    )
    values (
      p_user_id, v_locked.question_id, 1, v_presented_at,
      v_presented_at, 'solo', v_presented_at
    )
    on conflict (user_id, question_id) do update set
      exposure_count = public.learner_question_exposures.exposure_count + 1,
      last_presented_at = excluded.last_presented_at,
      last_source = excluded.last_source,
      updated_at = excluded.updated_at;
  end loop;

  select jsonb_agg(
    (question_item - 'hint') || jsonb_build_object(
      'questionRevisionId', locked.question_revision_id,
      'skillId', locked.skill_id,
      'hintAvailable', question.hint is not null
    )
    order by locked.question_order
  )
  into v_questions
  from jsonb_array_elements(v_response -> 'questions') question_item
  join public.practice_session_questions locked
    on locked.id = (question_item ->> 'sessionQuestionId')::uuid
  join public.questions question on question.id = locked.question_id
  where locked.session_id = v_session_id;

  if p_recommendation_id is not null then
    insert into public.recommendation_events(
      recommendation_id, user_id, event_type, idempotency_key,
      event_source, source_session_key, occurred_at
    )
    values (
      p_recommendation_id, p_user_id, 'session_started',
      'practice:' || v_session_id::text || ':started', 'server',
      v_session_id::text, v_presented_at
    )
    on conflict (recommendation_id, user_id, idempotency_key) do nothing;
  end if;

  return jsonb_set(
    v_response || jsonb_build_object(
      'recommendationId', p_recommendation_id,
      'calculationVersion', 'learning-v1',
      'evidenceCaptureVersion', 'compatibility-practice-v2',
      'compatibilityAdapter', 'practice_fixed_five'
    ),
    '{questions}', coalesce(v_questions, '[]'::jsonb), true
  );
end;
$$;

create or replace function public.request_practice_hint_learning_v2(
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
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_session public.practice_sessions%rowtype;
  v_hint text;
  v_hint_requested_at timestamptz;
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey must contain 1..160 characters';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object(
    'sessionId', p_session_id,
    'sessionQuestionId', p_session_question_id
  )::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':practice.hint:' || p_idempotency_key, 0
  ));

  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'practice.hint'
    and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_record.response;
  end if;

  select * into v_session from public.practice_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: practice session';
  end if;
  if v_session.finished_at is not null then
    raise exception using errcode = 'P0001', message = 'CONFLICT: practice session already finished';
  end if;
  if v_session.evidence_capture_version <> 'compatibility-practice-v2' then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: authoritative hint tracking is unavailable for this session';
  end if;

  select question.hint, locked.hint_requested_at
  into v_hint, v_hint_requested_at
  from public.practice_session_questions locked
  join public.questions question on question.id = locked.question_id
  where locked.id = p_session_question_id
    and locked.session_id = p_session_id
  for update of locked;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: practice question';
  end if;
  if nullif(btrim(v_hint), '') is null then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: hint is unavailable';
  end if;
  if exists (
    select 1 from public.practice_answers answer
    where answer.session_question_id = p_session_question_id
  ) then
    raise exception using errcode = 'P0001', message = 'CONFLICT: practice question already answered';
  end if;

  if v_hint_requested_at is null then
    v_hint_requested_at := p_requested_at;
    update public.practice_session_questions
    set hint_requested_at = v_hint_requested_at,
        hint_idempotency_key = p_idempotency_key
    where id = p_session_question_id;
  end if;

  v_response := jsonb_build_object(
    'sessionId', p_session_id,
    'sessionQuestionId', p_session_question_id,
    'hint', v_hint,
    'hintRequestedAt', v_hint_requested_at
  );
  insert into public.api_idempotency_records(
    user_id, operation, idempotency_key, request_hash, response
  ) values (
    p_user_id, 'practice.hint', p_idempotency_key, v_hash, v_response
  );
  return v_response;
end;
$$;

create or replace function public.submit_practice_answer_learning_v2(
  p_user_id uuid,
  p_session_id uuid,
  p_idempotency_key text,
  p_session_question_id uuid,
  p_selected_option_index integer,
  p_response_time_ms integer default null,
  p_answered_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.practice_sessions%rowtype;
  v_locked public.practice_session_questions%rowtype;
  v_revision public.question_revisions%rowtype;
  v_answer public.practice_answers%rowtype;
  v_attempt_id uuid;
  v_payload_hash text;
  v_classifier_hash text;
  v_hinted boolean;
  v_unseen boolean;
  v_revision_invalidated boolean;
  v_response jsonb;
  v_exclusions text[];
begin
  select * into v_session from public.practice_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: practice session';
  end if;
  if v_session.evidence_capture_version <> 'compatibility-practice-v2' then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: Learning V2 evidence capture is unavailable for this session';
  end if;

  select * into v_locked from public.practice_session_questions
  where id = p_session_question_id and session_id = p_session_id for update;
  if not found or v_locked.question_revision_id is null or v_locked.skill_id is null then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: practice question lacks a Learning V2 snapshot';
  end if;
  select * into v_revision from public.question_revisions
  where id = v_locked.question_revision_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: question revision';
  end if;

  v_hinted := v_locked.hint_requested_at is not null;
  v_unseen := v_locked.seen_before is false;
  v_revision_invalidated := exists (
    select 1 from public.learning_attempt_invalidations invalidation
    where invalidation.question_revision_id = v_revision.id
  );
  v_response := public.submit_practice_answer(
    p_user_id, p_session_id, p_idempotency_key, p_session_question_id,
    p_selected_option_index, p_response_time_ms, v_hinted, p_answered_at
  );

  select * into v_answer from public.practice_answers
  where session_question_id = p_session_question_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: persisted practice answer';
  end if;

  if v_answer.canonical_attempt_id is null then
    v_payload_hash := encode(extensions.digest(jsonb_build_object(
      'practiceAnswerId', v_answer.id,
      'questionRevisionId', v_revision.id,
      'selectedOptionIndex', v_answer.selected_option_index,
      'isCorrect', v_answer.is_correct,
      'hintRequested', v_hinted,
      'seenBefore', v_locked.seen_before,
      'answeredAt', v_answer.answered_at
    )::text, 'sha256'), 'hex');

    insert into public.learning_attempts(
      source, source_attempt_key, source_payload_hash, data_fidelity,
      user_id, target, source_session_key, recommendation_id,
      learning_objective, requested_mechanic_mode, effective_mechanic_mode,
      question_selection_type, session_completion_state,
      question_id, question_revision_id, taxonomy_version_id, skill_id,
      content_version, category, subcategory, difficulty, expected_time_ms,
      standard_time_limit_ms, curriculum_weight, question_quality_state,
      selected_option_index, is_correct, hint_requested, timed_out,
      first_attempt, seen_before, exposure_count_before, explanation_viewed,
      opened_at, answered_at, client_active_response_time_ms,
      timing_invalidity_reason, source_event_at
    ) values (
      'solo', 'practice:' || v_answer.id::text, v_payload_hash, 'compatibility_solo',
      p_user_id, v_session.target, p_session_id::text, v_session.recommendation_id,
      v_session.learning_objective, v_session.requested_mechanic_mode,
      v_session.effective_mechanic_mode, v_session.question_selection_type,
      case when (v_response #>> '{progress,isFinished}')::boolean
        then 'compatibility_completed' else 'in_progress' end,
      v_locked.question_id, v_revision.id, v_locked.taxonomy_version_id,
      v_locked.skill_id, v_revision.content_version, v_revision.category,
      v_revision.subcategory, v_revision.difficulty, v_revision.expected_time_ms,
      v_revision.standard_time_limit_ms, v_revision.curriculum_weight,
      v_revision.quality_state, v_answer.selected_option_index,
      v_answer.is_correct, v_hinted, false, true, v_locked.seen_before,
      v_locked.exposure_count_before, false, v_locked.opened_at,
      v_answer.answered_at, p_response_time_ms,
      'compatibility_timer_not_authoritative', v_answer.answered_at
    )
    on conflict (source, source_attempt_key) do nothing
    returning id into v_attempt_id;

    if v_attempt_id is null then
      select id, source_payload_hash into v_attempt_id, v_classifier_hash
      from public.learning_attempts
      where source = 'solo' and source_attempt_key = 'practice:' || v_answer.id::text;
      if v_classifier_hash <> v_payload_hash then
        raise exception using errcode = 'P0001', message = 'CONFLICT: canonical attempt payload differs';
      end if;
    end if;

    v_exclusions := array['compatibility_timer_not_authoritative']::text[];
    if v_hinted then v_exclusions := array_append(v_exclusions, 'hint_assisted'); end if;
    if not v_unseen then v_exclusions := array_append(v_exclusions, 'previously_exposed'); end if;
    if v_revision_invalidated then v_exclusions := array_append(v_exclusions, 'revision_invalidated'); end if;
    v_classifier_hash := encode(extensions.digest(jsonb_build_object(
      'attemptId', v_attempt_id,
      'classificationVersion', 'evidence-v1',
      'hintRequested', v_hinted,
      'seenBefore', v_locked.seen_before
    )::text, 'sha256'), 'hex');
    insert into public.learning_attempt_classifications(
      attempt_id, classification_version, classifier_input_hash,
      valid_for_activity_accuracy, valid_for_independent_accuracy,
      valid_for_unseen_independent_accuracy, valid_for_assisted_accuracy,
      valid_for_pace_analytics, valid_for_fluency_baseline,
      valid_for_retention, exclusion_reasons, classified_at
    ) values (
      v_attempt_id, 'evidence-v1', v_classifier_hash,
      not v_revision_invalidated,
      not v_revision_invalidated and not v_hinted,
      not v_revision_invalidated and not v_hinted and v_unseen,
      not v_revision_invalidated and v_hinted,
      false, false, false, v_exclusions, p_answered_at
    ) on conflict (attempt_id, classification_version) do nothing;

    update public.practice_answers
    set canonical_attempt_id = v_attempt_id
    where id = v_answer.id and canonical_attempt_id is null;
  else
    v_attempt_id := v_answer.canonical_attempt_id;
  end if;

  if (v_response #>> '{progress,isFinished}')::boolean
     and v_session.recommendation_id is not null then
    insert into public.recommendation_events(
      recommendation_id, user_id, event_type, idempotency_key,
      event_source, source_session_key, result_snapshot, occurred_at
    ) values (
      v_session.recommendation_id, p_user_id, 'session_completed',
      'practice:' || p_session_id::text || ':completed', 'server',
      p_session_id::text, v_response, p_answered_at
    ) on conflict (recommendation_id, user_id, idempotency_key) do nothing;
    update public.learning_recommendations
    set status = 'completed'
    where id = v_session.recommendation_id and status = 'active';
  end if;

  return v_response || jsonb_build_object('canonicalAttemptId', v_attempt_id);
end;
$$;

create or replace function public.finish_practice_session_learning_v2(
  p_user_id uuid,
  p_session_id uuid,
  p_idempotency_key text,
  p_completed_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_response jsonb;
  v_recommendation_id uuid;
begin
  v_response := public.finish_practice_session(
    p_user_id, p_session_id, p_idempotency_key, p_completed_at
  );
  select recommendation_id into v_recommendation_id
  from public.practice_sessions
  where id = p_session_id and user_id = p_user_id;
  if v_recommendation_id is not null then
    insert into public.recommendation_events(
      recommendation_id, user_id, event_type, idempotency_key,
      event_source, source_session_key, result_snapshot, occurred_at
    ) values (
      v_recommendation_id, p_user_id, 'session_completed',
      'practice:' || p_session_id::text || ':completed', 'server',
      p_session_id::text, v_response, p_completed_at
    ) on conflict (recommendation_id, user_id, idempotency_key) do nothing;
    update public.learning_recommendations
    set status = 'completed'
    where id = v_recommendation_id and status = 'active';
  end if;
  return v_response;
end;
$$;

create or replace function public.claim_learning_projection_jobs(
  p_worker_id text,
  p_limit integer default 25,
  p_now timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_jobs jsonb;
begin
  if nullif(btrim(p_worker_id), '') is null then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: worker ID is required';
  end if;
  if p_limit not between 1 and 100 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: limit must be between 1 and 100';
  end if;
  with selected as (
    select job.id
    from public.learning_projection_jobs job
    where job.status in ('pending', 'failed')
      and job.available_at <= p_now
      and job.attempt_count < 10
    order by job.available_at, job.created_at, job.id
    for update skip locked
    limit p_limit
  ), claimed as (
    update public.learning_projection_jobs job
    set status = 'processing', attempt_count = job.attempt_count + 1,
        locked_at = p_now, locked_by = p_worker_id,
        last_error = null, updated_at = p_now
    from selected
    where job.id = selected.id
    returning job.*
  )
  select coalesce(jsonb_agg(to_jsonb(claimed) order by claimed.created_at, claimed.id), '[]'::jsonb)
  into v_jobs from claimed;
  return v_jobs;
end;
$$;

create or replace function public.ingest_pvp_learning_evidence(
  p_match_result_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_match public.match_results%rowtype;
  v_log record;
  v_attempt_id uuid;
  v_existing_hash text;
  v_payload_hash text;
  v_classifier_hash text;
  v_inserted integer := 0;
  v_existing integer := 0;
begin
  select * into v_match
  from public.match_results
  where id = p_match_result_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: match result';
  end if;
  if v_match.target not in ('cpns', 'bumn')
     or v_match.mode not in ('casual', 'ranked', 'private') then
    return jsonb_build_object(
      'matchResultId', p_match_result_id,
      'inserted', 0,
      'existing', 0,
      'skipped', true
    );
  end if;

  for v_log in
    select log.*
    from public.match_logs log
    where log.match_result_id = p_match_result_id
      and log.player_id is not null
      and log.is_correct is not null
      and log.action_type in ('play_card', 'timeout')
    order by log.action_timestamp, log.id
  loop
    v_payload_hash := encode(extensions.digest(jsonb_build_object(
      'matchResultId', p_match_result_id,
      'matchLogId', v_log.id,
      'userId', v_log.player_id,
      'target', v_match.target,
      'mode', v_match.mode,
      'questionId', v_log.question_id,
      'selectedOptionIndex', v_log.selected_option_index,
      'isCorrect', v_log.is_correct,
      'timedOut', v_log.action_type = 'timeout',
      'actionTimestamp', v_log.action_timestamp
    )::text, 'sha256'), 'hex');

    v_attempt_id := null;
    insert into public.learning_attempts(
      source, source_attempt_key, source_payload_hash, data_fidelity,
      user_id, target, source_session_key, pvp_mode,
      question_id, selected_option_index, is_correct, hint_requested,
      timed_out, first_attempt, seen_before,
      client_active_response_time_ms, effective_response_time_ms,
      timing_invalidity_reason, answered_at, source_event_at
    ) values (
      'pvp', 'pvp:' || v_log.id::text, v_payload_hash, 'legacy_pvp',
      v_log.player_id, v_match.target, p_match_result_id::text, v_match.mode,
      v_log.question_id, v_log.selected_option_index, v_log.is_correct, null,
      v_log.action_type = 'timeout', null, null,
      v_log.response_time_ms, null,
      'pvp_timing_not_eligible_for_solo', v_log.action_timestamp,
      v_log.action_timestamp
    )
    on conflict (source, source_attempt_key) do nothing
    returning id into v_attempt_id;

    if v_attempt_id is null then
      select attempt.id, attempt.source_payload_hash
      into v_attempt_id, v_existing_hash
      from public.learning_attempts attempt
      where attempt.source = 'pvp'
        and attempt.source_attempt_key = 'pvp:' || v_log.id::text;
      if v_existing_hash <> v_payload_hash then
        raise exception using errcode = 'P0001', message = 'CONFLICT: canonical PvP attempt payload differs';
      end if;
      v_existing := v_existing + 1;
    else
      v_inserted := v_inserted + 1;
    end if;

    v_classifier_hash := encode(extensions.digest(jsonb_build_object(
      'attemptId', v_attempt_id,
      'classificationVersion', 'evidence-v1',
      'source', 'pvp',
      'competitionContextSeparate', true
    )::text, 'sha256'), 'hex');
    insert into public.learning_attempt_classifications(
      attempt_id, classification_version, classifier_input_hash,
      valid_for_activity_accuracy, valid_for_independent_accuracy,
      valid_for_unseen_independent_accuracy, valid_for_assisted_accuracy,
      valid_for_pace_analytics, valid_for_fluency_baseline,
      valid_for_retention, exclusion_reasons, classified_at
    ) values (
      v_attempt_id, 'evidence-v1', v_classifier_hash,
      true, false, false, false, false, false, false,
      array[
        'competition_context_separate', 'revision_unknown',
        'skill_eligibility_unknown', 'hint_eligibility_unknown',
        'exposure_eligibility_unknown', 'timing_eligibility_unknown'
      ]::text[], v_log.action_timestamp
    ) on conflict (attempt_id, classification_version) do nothing;
  end loop;

  return jsonb_build_object(
    'matchResultId', p_match_result_id,
    'inserted', v_inserted,
    'existing', v_existing,
    'skipped', false
  );
end;
$$;

create or replace function public.reconcile_recent_pvp_learning_evidence(
  p_since timestamptz default (clock_timestamp() - interval '2 days'),
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
  v_result jsonb;
  v_matches integer := 0;
  v_attempts integer := 0;
begin
  if p_limit not between 1 and 500 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: limit must be between 1 and 500';
  end if;
  for v_match in
    select distinct result.id, result.ended_at
    from public.match_results result
    join public.match_logs log on log.match_result_id = result.id
    where result.ended_at >= p_since
      and result.target in ('cpns', 'bumn')
      and result.mode in ('casual', 'ranked', 'private')
      and log.player_id is not null
      and log.is_correct is not null
      and log.action_type in ('play_card', 'timeout')
      and not exists (
        select 1
        from public.learning_attempts attempt
        where attempt.source = 'pvp'
          and attempt.source_attempt_key = 'pvp:' || log.id::text
      )
    order by result.ended_at, result.id
    limit p_limit
  loop
    v_result := public.ingest_pvp_learning_evidence(v_match.id);
    v_matches := v_matches + 1;
    v_attempts := v_attempts + coalesce((v_result ->> 'inserted')::integer, 0);
  end loop;
  return jsonb_build_object('matchesProcessed', v_matches, 'attemptsInserted', v_attempts);
end;
$$;

revoke all on function public.create_practice_session_learning_v2(uuid, text, text, uuid) from public, anon, authenticated;
revoke all on function public.request_practice_hint_learning_v2(uuid, uuid, uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.submit_practice_answer_learning_v2(uuid, uuid, text, uuid, integer, integer, timestamptz) from public, anon, authenticated;
revoke all on function public.finish_practice_session_learning_v2(uuid, uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.claim_learning_projection_jobs(text, integer, timestamptz) from public, anon, authenticated;
revoke all on function public.ingest_pvp_learning_evidence(uuid) from public, anon, authenticated;
revoke all on function public.reconcile_recent_pvp_learning_evidence(timestamptz, integer) from public, anon, authenticated;

grant execute on function public.create_practice_session_learning_v2(uuid, text, text, uuid) to service_role;
grant execute on function public.request_practice_hint_learning_v2(uuid, uuid, uuid, text, timestamptz) to service_role;
grant execute on function public.submit_practice_answer_learning_v2(uuid, uuid, text, uuid, integer, integer, timestamptz) to service_role;
grant execute on function public.finish_practice_session_learning_v2(uuid, uuid, text, timestamptz) to service_role;
grant execute on function public.claim_learning_projection_jobs(text, integer, timestamptz) to service_role;
grant execute on function public.ingest_pvp_learning_evidence(uuid) to service_role;
grant execute on function public.reconcile_recent_pvp_learning_evidence(timestamptz, integer) to service_role;

commit;
