-- Deal Solo questions in a server-owned three-card hand and track hint use.

alter table public.solo_answers
  add column if not exists used_hint boolean not null default false;

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
    'mechanicMode', v_session.mechanic_mode,
    'questionSelection', v_session.question_selection,
    'questionCount', v_session.question_count,
    'characterId', v_session.character_id,
    'status', v_session.status,
    'completionReason', v_session.completion_reason,
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
  v_available_rank integer;
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
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':solo.open:' || p_idempotency_key, 0));
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'solo.open' and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    return v_record.response;
  end if;

  select * into v_session from public.solo_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo session'; end if;
  if v_session.status <> 'active' then raise exception using errcode = 'P0001', message = 'CONFLICT: solo session finished'; end if;

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
  if v_sq.opened_at is null then
    v_sq.opened_at := clock_timestamp();
    v_sq.deadline_at := v_sq.opened_at + make_interval(secs => greatest(v_question.time_limit_seconds, 1));
    update public.solo_session_questions
    set opened_at = v_sq.opened_at, deadline_at = v_sq.deadline_at
    where id = v_sq.id;
  end if;

  v_response := jsonb_build_object(
    'sessionQuestionId', v_sq.id,
    'questionId', v_question.id,
    'questionOrder', v_sq.question_order,
    'category', v_question.category,
    'subcategory', v_question.subcategory,
    'prompt', v_question.prompt,
    'options', v_question.options,
    'timeLimitSeconds', v_question.time_limit_seconds,
    'hint', v_question.hint,
    'openedAt', v_sq.opened_at,
    'deadlineAt', v_sq.deadline_at
  );
  insert into public.api_idempotency_records(user_id, operation, idempotency_key, request_hash, response)
  values (p_user_id, 'solo.open', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

drop function if exists public.submit_solo_answer(uuid, uuid, text, uuid, integer, timestamptz);
create or replace function public.submit_solo_answer(
  p_user_id uuid,
  p_session_id uuid,
  p_idempotency_key text,
  p_session_question_id uuid,
  p_selected_option_index integer default null,
  p_used_hint boolean default false,
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
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_timed_out boolean;
  v_is_correct boolean;
  v_answered integer;
  v_correct integer;
  v_hp integer;
  v_reason text;
  v_requested_reward integer := 0;
  v_reward integer := 0;
  v_earned_today integer := 0;
  v_balance integer;
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object(
    'sessionId', p_session_id, 'sessionQuestionId', p_session_question_id,
    'selectedOptionIndex', p_selected_option_index, 'usedHint', p_used_hint
  )::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':solo.answer:' || p_idempotency_key, 0));
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'solo.answer' and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    return v_record.response;
  end if;

  select * into v_session from public.solo_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo session'; end if;
  if v_session.status <> 'active' then raise exception using errcode = 'P0001', message = 'CONFLICT: solo session finished'; end if;
  select * into v_sq from public.solo_session_questions
  where id = p_session_question_id and session_id = p_session_id for update;
  if not found or v_sq.resolved_at is not null then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo question'; end if;
  if v_sq.opened_at is null or v_sq.deadline_at is null then raise exception using errcode = 'P0001', message = 'CONFLICT: question is not open'; end if;
  select * into v_question from public.questions where id = v_sq.question_id;

  v_timed_out := p_answered_at >= v_sq.deadline_at;
  if not v_timed_out and (p_selected_option_index is null or p_selected_option_index < 0
      or p_selected_option_index >= jsonb_array_length(v_question.options)) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: selectedOptionIndex';
  end if;
  v_is_correct := not v_timed_out and p_selected_option_index = v_question.correct_option_index;

  insert into public.solo_answers(
    session_id, session_question_id, user_id, question_id, selected_option_index,
    is_correct, timed_out, used_hint, response_time_ms, correct_option_index_snapshot,
    explanation_snapshot, answered_at
  ) values (
    p_session_id, v_sq.id, p_user_id, v_question.id,
    case when v_timed_out then null else p_selected_option_index end,
    v_is_correct, v_timed_out, p_used_hint,
    greatest(0, floor(extract(epoch from (least(p_answered_at, v_sq.deadline_at) - v_sq.opened_at)) * 1000)::integer),
    v_question.correct_option_index, v_question.explanation, p_answered_at
  );
  update public.solo_session_questions set resolved_at = p_answered_at where id = v_sq.id;

  select count(*), count(*) filter (where is_correct) into v_answered, v_correct
  from public.solo_answers where session_id = p_session_id;
  v_hp := ceil(100.0 * (v_session.question_count - v_correct) / v_session.question_count)::integer;
  update public.solo_sessions set answered_count = v_answered, correct_count = v_correct,
    tower_hp = v_hp, updated_at = p_answered_at where id = p_session_id;

  if v_answered = v_session.question_count then
    v_reason := case when v_correct = v_session.question_count then 'tower_destroyed' else 'questions_completed' end;
    v_requested_reward := case when v_reason = 'tower_destroyed' then 10 else 3 end;
    select coalesce(sum(delta), 0) into v_earned_today from public.coin_transactions
    where user_id = p_user_id and reason = 'solo_reward'
      and public.wib_business_date(created_at) = public.wib_business_date(p_answered_at);
    v_reward := least(v_requested_reward, greatest(30 - v_earned_today, 0));
    if v_reward > 0 then
      update public.profiles set coins = coins + v_reward, updated_at = p_answered_at
      where id = p_user_id returning coins into v_balance;
      insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
      values (p_user_id, v_reward, 'solo_reward', p_session_id::text, 'solo:' || p_session_id, v_balance);
    end if;
    update public.solo_sessions set status = 'completed', completion_reason = v_reason,
      reward_coins = v_reward, finished_at = p_answered_at, updated_at = p_answered_at
    where id = p_session_id;
  end if;

  v_response := public.solo_session_payload(p_user_id, p_session_id) || jsonb_build_object(
    'answerResult', jsonb_build_object(
      'sessionQuestionId', v_sq.id, 'isCorrect', v_is_correct, 'timedOut', v_timed_out,
      'correctOptionIndex', v_question.correct_option_index, 'explanation', v_question.explanation
    )
  );
  insert into public.api_idempotency_records(user_id, operation, idempotency_key, request_hash, response)
  values (p_user_id, 'solo.answer', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

revoke all on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, boolean, timestamptz)
  from public, anon, authenticated;
grant execute on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, boolean, timestamptz)
  to service_role;

notify pgrst, 'reload schema';
