-- Restore canonical Solo evidence without changing focus/speed gameplay.
-- Run this whole file in the cloud SQL editor. Recovery is a separate script.
begin;

create or replace function public.ingest_solo_answer_learning_evidence(p_answer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_answer public.solo_answers%rowtype;
  v_session public.solo_sessions%rowtype;
  v_sq public.solo_session_questions%rowtype;
  v_revision public.question_revisions%rowtype;
  v_attempt public.learning_attempts%rowtype;
  v_complete boolean;
  v_invalidated boolean;
  v_timing_invalidity text;
  v_effective_ms integer;
  v_completion_state text;
  v_payload_hash text;
  v_inserted boolean := false;
  v_exclusions text[] := '{}';
begin
  -- Serialize replay/backfill for this source answer. Never replay gameplay,
  -- rewards, energy charges, or question-exposure increments during recovery.
  select * into strict v_answer from public.solo_answers
  where id = p_answer_id for update;
  select * into strict v_session from public.solo_sessions
  where id = v_answer.session_id;
  select * into strict v_sq from public.solo_session_questions
  where id = v_answer.session_question_id;
  if v_session.user_id <> v_answer.user_id
     or v_sq.session_id <> v_session.id
     or v_sq.question_id <> v_answer.question_id then
    raise exception 'VALIDATION_FAILED: solo answer ownership mismatch';
  end if;

  select * into v_attempt from public.learning_attempts
  where source = 'solo' and source_attempt_key = 'solo:' || v_answer.id::text;
  if found then
    if v_attempt.user_id <> v_answer.user_id
       or v_attempt.source_session_key is distinct from v_session.id::text
       or v_attempt.question_id is distinct from v_answer.question_id then
      raise exception 'CONFLICT: solo canonical source mismatch';
    end if;
  else
    if v_answer.canonical_attempt_id is not null then
      raise exception 'CONFLICT: solo canonical link mismatch';
    end if;
    select * into v_revision from public.question_revisions
    where id = v_sq.question_revision_id;
    -- Use the revision/mapping captured when the question was opened, never
    -- today's question content or a guessed skill for pre-alignment answers.
    v_complete := v_revision.id is not null
      and v_revision.question_id = v_answer.question_id
      and v_revision.target = v_session.target
      and v_sq.taxonomy_version_id is not null and v_sq.skill_id is not null
      and v_sq.opened_at is not null
      and v_sq.seen_before is not null and v_sq.exposure_count_before is not null;

    if not v_complete then
      v_timing_invalidity := 'legacy_metadata_incomplete';
    elsif v_answer.client_active_response_time_ms is null then
      v_timing_invalidity := 'client_active_time_missing';
    elsif v_answer.response_time_ms is null then
      v_timing_invalidity := 'server_elapsed_time_missing';
    elsif v_answer.client_active_response_time_ms > v_answer.response_time_ms + 2000 then
      v_timing_invalidity := 'client_active_time_exceeds_server_elapsed';
    elsif v_answer.background_duration_ms is not null
      and v_answer.client_active_response_time_ms + v_answer.background_duration_ms
        > v_answer.response_time_ms + 2000 then
      v_timing_invalidity := 'client_timing_components_exceed_server_elapsed';
    end if;
    if v_timing_invalidity is null then
      v_effective_ms := v_answer.client_active_response_time_ms;
    end if;

    -- Preserve completion as observed at this answer, not the later stop state.
    select case when count(*) >= v_session.question_count
      then 'policy_completed' else 'in_progress' end into v_completion_state
    from public.solo_answers
    where session_id = v_session.id and answered_at <= v_answer.answered_at;
    v_payload_hash := encode(extensions.digest(jsonb_build_object(
      'soloAnswerId', v_answer.id, 'questionRevisionId', v_revision.id,
      'selectedOptionIndex', v_answer.selected_option_index,
      'isCorrect', v_answer.is_correct, 'timedOut', v_answer.timed_out,
      'hintRequested', v_answer.used_hint, 'seenBefore', v_sq.seen_before,
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
      first_attempt, seen_before, exposure_count_before,
      opened_at, answered_at, deadline_at, client_active_response_time_ms,
      server_elapsed_time_ms, background_duration_ms,
      effective_response_time_ms, timing_invalidity_reason, source_event_at
    ) values (
      'solo', 'solo:' || v_answer.id::text, v_payload_hash,
      case when v_complete then 'v2_complete' else 'legacy_solo' end,
      v_answer.user_id, v_session.target, v_session.id::text, v_session.recommendation_id,
      v_session.learning_objective, v_session.requested_mechanic_mode,
      v_session.effective_mechanic_mode, v_session.question_selection_type,
      v_session.policy_id || ':v' || v_session.policy_version, v_completion_state,
      v_answer.question_id, v_revision.id,
      case when v_complete then v_sq.taxonomy_version_id end,
      case when v_complete then v_sq.skill_id end,
      v_revision.content_version, v_revision.category, v_revision.subcategory,
      v_revision.difficulty, v_revision.expected_time_ms, v_revision.standard_time_limit_ms,
      v_revision.curriculum_weight, v_revision.quality_state,
      v_answer.selected_option_index, v_answer.is_correct,
      case when v_complete then v_answer.used_hint end, v_answer.timed_out,
      case when v_complete then true end, v_sq.seen_before, v_sq.exposure_count_before,
      v_sq.opened_at, v_answer.answered_at, v_sq.deadline_at,
      v_answer.client_active_response_time_ms, v_answer.response_time_ms,
      v_answer.background_duration_ms, v_effective_ms, v_timing_invalidity,
      v_answer.answered_at
    ) returning * into v_attempt;
    v_inserted := true;
  end if;

  if v_answer.canonical_attempt_id is not null
     and v_answer.canonical_attempt_id <> v_attempt.id then
    raise exception 'CONFLICT: solo canonical link mismatch';
  end if;

  -- Classifications are immutable: repair a missing row, never rewrite one.
  if not exists (
    select 1 from public.learning_attempt_classifications
    where attempt_id = v_attempt.id and classification_version = 'evidence-v1'
  ) then
    v_complete := v_attempt.data_fidelity = 'v2_complete';
    v_invalidated := exists (
      select 1 from public.learning_attempt_invalidations
      where attempt_id = v_attempt.id or question_revision_id = v_attempt.question_revision_id
    );
    if not v_complete then v_exclusions := array_append(v_exclusions, 'legacy_metadata_incomplete'); end if;
    if v_invalidated then v_exclusions := array_append(v_exclusions, 'revision_invalidated'); end if;
    if v_attempt.hint_requested then v_exclusions := array_append(v_exclusions, 'hint_assisted'); end if;
    if v_attempt.seen_before then v_exclusions := array_append(v_exclusions, 'previously_exposed'); end if;
    if v_attempt.timed_out then v_exclusions := array_append(v_exclusions, 'timed_out'); end if;
    if v_attempt.timing_invalidity_reason is not null then
      v_exclusions := array_append(v_exclusions, v_attempt.timing_invalidity_reason);
    end if;
    insert into public.learning_attempt_classifications(
      attempt_id, classification_version, classifier_input_hash,
      valid_for_activity_accuracy, valid_for_independent_accuracy,
      valid_for_unseen_independent_accuracy, valid_for_assisted_accuracy,
      valid_for_pace_analytics, valid_for_fluency_baseline,
      valid_for_retention, exclusion_reasons
    ) values (
      v_attempt.id, 'evidence-v1', encode(extensions.digest(jsonb_build_object(
        'attemptId', v_attempt.id, 'classificationVersion', 'evidence-v1',
        'hintRequested', v_attempt.hint_requested, 'seenBefore', v_attempt.seen_before,
        'timedOut', v_attempt.timed_out,
        'timingInvalidityReason', v_attempt.timing_invalidity_reason,
        'exclusionReasons', v_exclusions
      )::text, 'sha256'), 'hex'),
      v_complete and not v_invalidated,
      v_complete and not v_invalidated and v_attempt.hint_requested is false,
      v_complete and not v_invalidated and v_attempt.hint_requested is false and v_attempt.seen_before is false,
      v_complete and not v_invalidated and v_attempt.hint_requested is true,
      v_complete and not v_invalidated and v_attempt.hint_requested is false
        and not v_attempt.timed_out and v_attempt.timing_invalidity_reason is null,
      v_complete and not v_invalidated and v_attempt.hint_requested is false
        and not v_attempt.timed_out and v_attempt.timing_invalidity_reason is null,
      v_complete and not v_invalidated and v_attempt.hint_requested is false and v_attempt.seen_before is false,
      v_exclusions
    ) on conflict (attempt_id, classification_version) do nothing;
    if not v_inserted then
      perform public.enqueue_learning_projection(
        v_attempt.user_id, v_attempt.target, v_attempt.taxonomy_version_id,
        v_attempt.skill_id, 'backfill', v_attempt.id
      );
    end if;
  end if;

  update public.solo_answers set canonical_attempt_id = v_attempt.id
  where id = v_answer.id and canonical_attempt_id is null;
  return v_attempt.id;
end;
$$;

revoke all on function public.ingest_solo_answer_learning_evidence(uuid) from public, anon, authenticated;
grant execute on function public.ingest_solo_answer_learning_evidence(uuid) to service_role;

-- The current submit_solo_answer definition follows below, with ingestion
-- restored after gameplay state is persisted in the same transaction.
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
  v_record public.api_idempotency_records%rowtype;
  v_timed_out boolean;
  v_is_correct boolean;
  v_hinted boolean;
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
  v_response jsonb;
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
    -- Old cached responses may predate canonical ingestion. Repair only the
    -- evidence/link; retain the original gameplay result on idempotent replay.
    select * into strict v_answer from public.solo_answers
    where user_id = p_user_id and session_id = p_session_id
      and session_question_id = p_session_question_id;
    v_attempt_id := public.ingest_solo_answer_learning_evidence(v_answer.id);
    return v_record.response || jsonb_build_object(
      'attemptId', v_attempt_id,
      'answerResult', (v_record.response -> 'answerResult') || jsonb_build_object('attemptId', v_attempt_id)
    );
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
    v_answer.canonical_attempt_id := public.ingest_solo_answer_learning_evidence(v_answer.id);
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
  if v_sq.opened_at is null or (v_session.effective_mechanic_mode <> 'focus' and v_sq.deadline_at is null) or v_sq.question_revision_id is null then
    raise exception using errcode = 'P0001', message = 'CONFLICT: solo question is not open';
  end if;
  select * into v_question from public.questions where id = v_sq.question_id;
  select * into v_revision from public.question_revisions where id = v_sq.question_revision_id;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: question revision'; end if;

  if v_session.effective_mechanic_mode = 'focus' or v_session.mechanic_mode = 'focus' then
    v_timed_out := false;
  else
    v_timed_out := (v_sq.deadline_at is not null and p_answered_at >= v_sq.deadline_at);
  end if;
  if not v_timed_out and (p_selected_option_index is null
      or p_selected_option_index < 0
      or p_selected_option_index >= jsonb_array_length(v_revision.options)) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: selectedOptionIndex';
  end if;
  v_is_correct := not v_timed_out
    and p_selected_option_index = v_revision.correct_option_index;
  v_hinted := v_sq.hint_requested_at is not null;
  v_server_elapsed_ms := greatest(0, floor(extract(epoch from (
    case when v_sq.deadline_at is not null then least(p_answered_at, v_sq.deadline_at) else p_answered_at end - v_sq.opened_at
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
    v_reward := greatest(0, least(v_requested_reward, 30 - v_earned_today));
    if v_reward > 0 then
      update public.profiles
      set coins = coins + v_reward, updated_at = p_answered_at
      where id = p_user_id returning coins into v_balance;

      insert into public.coin_transactions(
        user_id, delta, reason, reference_id, idempotency_key, balance_after
      ) values (
        p_user_id, v_reward, 'solo_reward', p_session_id::text,
        'solo:' || p_session_id::text, v_balance
      ) on conflict (user_id, idempotency_key) do nothing;
    else
      select coins into v_balance from public.profiles where id = p_user_id;
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

  v_attempt_id := public.ingest_solo_answer_learning_evidence(v_answer.id);
  v_answer.canonical_attempt_id := v_attempt_id;
  v_response := public.solo_session_payload(p_user_id, p_session_id) || jsonb_build_object(
    'attemptId', v_answer.canonical_attempt_id,
    'answerResult', jsonb_build_object(
      'sessionQuestionId', v_sq.id,
      'attemptId', v_answer.canonical_attempt_id,
      'isCorrect', v_is_correct,
      'timedOut', v_timed_out,
      'correctOptionIndex', v_revision.correct_option_index,
      'explanation', v_revision.explanation
    )
  );
  insert into public.api_idempotency_records(
    user_id, operation, idempotency_key, request_hash, response
  ) values (p_user_id, 'solo.answer', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;


revoke all on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, integer, integer, timestamptz) from public, anon, authenticated;
grant execute on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, integer, integer, timestamptz) to service_role;

notify pgrst, 'reload schema';
commit;
