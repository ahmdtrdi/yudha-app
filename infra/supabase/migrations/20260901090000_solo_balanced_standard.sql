-- Commit 5: first operational Solo slice (Balanced + Standard).

alter table public.coin_transactions drop constraint if exists coin_transactions_reason_check;
alter table public.coin_transactions add constraint coin_transactions_reason_check check (
  reason in ('match_reward', 'solo_reward', 'store_purchase', 'hired_pass_reward', 'beta_credit', 'admin')
);

create table if not exists public.solo_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null check (target in ('cpns', 'bumn')),
  mechanic_mode text not null check (mechanic_mode = 'standard'),
  question_selection text not null check (question_selection = 'balanced'),
  question_count integer not null check (question_count in (20, 35, 50)),
  character_id text not null,
  policy_id text not null default 'solo-fixed-count-v1',
  policy_version integer not null default 1,
  status text not null default 'active' check (status in ('active', 'completed', 'stopped')),
  completion_reason text check (completion_reason in ('tower_destroyed', 'questions_completed', 'user_stopped')),
  answered_count integer not null default 0,
  correct_count integer not null default 0,
  tower_hp integer not null default 100 check (tower_hp between 0 and 100),
  reward_coins integer not null default 0 check (reward_coins >= 0),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  updated_at timestamptz not null default now(),
  check (answered_count between 0 and question_count),
  check (correct_count between 0 and answered_count)
);

create table if not exists public.solo_session_questions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.solo_sessions(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  question_order integer not null,
  opened_at timestamptz,
  deadline_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (session_id, question_id),
  unique (session_id, question_order)
);

create table if not exists public.solo_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.solo_sessions(id) on delete cascade,
  session_question_id uuid not null references public.solo_session_questions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  selected_option_index integer,
  is_correct boolean not null,
  timed_out boolean not null default false,
  response_time_ms integer,
  correct_option_index_snapshot integer not null,
  explanation_snapshot text not null,
  answered_at timestamptz not null default now(),
  unique (session_question_id),
  check (selected_option_index is null or selected_option_index between 0 and 5),
  check (response_time_ms is null or response_time_ms >= 0),
  check (not timed_out or selected_option_index is null)
);

create index if not exists solo_sessions_user_started_idx
  on public.solo_sessions(user_id, started_at desc);
create unique index if not exists solo_sessions_one_active_per_user_idx
  on public.solo_sessions(user_id) where status = 'active';
create index if not exists solo_session_questions_session_order_idx
  on public.solo_session_questions(session_id, question_order);

alter table public.solo_sessions enable row level security;
alter table public.solo_session_questions enable row level security;
alter table public.solo_answers enable row level security;

drop policy if exists "Users can read their own solo sessions" on public.solo_sessions;
create policy "Users can read their own solo sessions" on public.solo_sessions
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can read their own solo session questions" on public.solo_session_questions;
create policy "Users can read their own solo session questions" on public.solo_session_questions
  for select to authenticated using (
    exists (select 1 from public.solo_sessions s where s.id = session_id and s.user_id = auth.uid())
  );
drop policy if exists "Users can read their own solo answers" on public.solo_answers;
create policy "Users can read their own solo answers" on public.solo_answers
  for select to authenticated using (auth.uid() = user_id);

create or replace function public.solo_session_payload(p_user_id uuid, p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.solo_sessions%rowtype;
  v_questions jsonb;
begin
  select * into v_session from public.solo_sessions
  where id = p_session_id and user_id = p_user_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo session';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'sessionQuestionId', sq.id,
    'questionId', q.id,
    'questionOrder', sq.question_order,
    'category', q.category,
    'subcategory', q.subcategory,
    'prompt', q.prompt,
    'options', q.options,
    'timeLimitSeconds', q.time_limit_seconds,
    'openedAt', sq.opened_at,
    'deadlineAt', sq.deadline_at,
    'answered', a.id is not null,
    'selectedOptionIndex', a.selected_option_index,
    'isCorrect', a.is_correct,
    'timedOut', coalesce(a.timed_out, false),
    'correctOptionIndex', case when a.id is not null then a.correct_option_index_snapshot end,
    'explanation', case when a.id is not null then a.explanation_snapshot end
  ) order by sq.question_order), '[]'::jsonb)
  into v_questions
  from public.solo_session_questions sq
  join public.questions q on q.id = sq.question_id
  left join public.solo_answers a on a.session_question_id = sq.id
  where sq.session_id = p_session_id;

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
    'questions', v_questions
  );
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
begin
  select id into v_session_id from public.solo_sessions
  where user_id = p_user_id and status = 'active'
  order by started_at desc limit 1;
  return jsonb_build_object(
    'activeSession',
    case when v_session_id is null then null
      else public.solo_session_payload(p_user_id, v_session_id) end
  );
end;
$$;

create or replace function public.create_solo_session(
  p_user_id uuid,
  p_idempotency_key text,
  p_mechanic_mode text,
  p_question_selection text,
  p_question_count integer,
  p_character_id text
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
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  if p_mechanic_mode <> 'standard' or p_question_selection <> 'balanced' then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: only Balanced + Standard is available';
  end if;
  if p_question_count not in (20, 35, 50) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: questionCount';
  end if;
  if p_character_id is null or btrim(p_character_id) = '' then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: characterId';
  end if;

  v_hash := encode(extensions.digest(jsonb_build_object(
    'mechanicMode', p_mechanic_mode, 'questionSelection', p_question_selection,
    'questionCount', p_question_count, 'characterId', p_character_id
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
    (user_id, target, mechanic_mode, question_selection, question_count, character_id)
  values
    (p_user_id, v_target, p_mechanic_mode, p_question_selection, p_question_count, btrim(p_character_id))
  returning id into v_session_id;

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
  v_question_id uuid;
  v_order integer;
  v_opened timestamptz;
  v_deadline timestamptz;
  v_limit integer;
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

  select sq.question_id, sq.question_order, sq.opened_at, sq.deadline_at, q.time_limit_seconds
  into v_question_id, v_order, v_opened, v_deadline, v_limit
  from public.solo_session_questions sq join public.questions q on q.id = sq.question_id
  where sq.id = p_session_question_id and sq.session_id = p_session_id for update of sq;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo question'; end if;
  if v_order <> v_session.answered_count + 1 then raise exception using errcode = 'P0001', message = 'CONFLICT: question is not current'; end if;

  if v_opened is null then
    v_opened := clock_timestamp();
    v_deadline := v_opened + make_interval(secs => greatest(v_limit, 1));
    update public.solo_session_questions set opened_at = v_opened, deadline_at = v_deadline
    where id = p_session_question_id;
  end if;
  v_response := jsonb_build_object('sessionQuestionId', p_session_question_id, 'openedAt', v_opened, 'deadlineAt', v_deadline);
  insert into public.api_idempotency_records(user_id, operation, idempotency_key, request_hash, response)
  values (p_user_id, 'solo.open', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

create or replace function public.submit_solo_answer(
  p_user_id uuid,
  p_session_id uuid,
  p_idempotency_key text,
  p_session_question_id uuid,
  p_selected_option_index integer default null,
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
    'selectedOptionIndex', p_selected_option_index
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
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo question'; end if;
  if v_sq.question_order <> v_session.answered_count + 1 then raise exception using errcode = 'P0001', message = 'CONFLICT: question is not current'; end if;
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
    is_correct, timed_out, response_time_ms, correct_option_index_snapshot,
    explanation_snapshot, answered_at
  ) values (
    p_session_id, v_sq.id, p_user_id, v_question.id,
    case when v_timed_out then null else p_selected_option_index end,
    v_is_correct, v_timed_out,
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

create or replace function public.finish_solo_session(
  p_user_id uuid,
  p_session_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.solo_sessions%rowtype;
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object('sessionId', p_session_id, 'reason', 'user_stopped')::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':solo.finish:' || p_idempotency_key, 0));
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'solo.finish' and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    return v_record.response;
  end if;
  select * into v_session from public.solo_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: solo session'; end if;
  if v_session.status = 'active' then
    update public.solo_sessions set status = 'stopped', completion_reason = 'user_stopped',
      reward_coins = 0, finished_at = clock_timestamp(), updated_at = clock_timestamp()
    where id = p_session_id;
  end if;
  v_response := public.solo_session_payload(p_user_id, p_session_id);
  insert into public.api_idempotency_records(user_id, operation, idempotency_key, request_hash, response)
  values (p_user_id, 'solo.finish', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

revoke all on function public.solo_session_payload(uuid, uuid) from public, anon, authenticated;
revoke all on function public.get_active_solo_session(uuid) from public, anon, authenticated;
revoke all on function public.create_solo_session(uuid, text, text, text, integer, text) from public, anon, authenticated;
revoke all on function public.open_solo_question(uuid, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, timestamptz) from public, anon, authenticated;
revoke all on function public.finish_solo_session(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.solo_session_payload(uuid, uuid) to service_role;
grant execute on function public.get_active_solo_session(uuid) to service_role;
grant execute on function public.create_solo_session(uuid, text, text, text, integer, text) to service_role;
grant execute on function public.open_solo_question(uuid, uuid, uuid, text) to service_role;
grant execute on function public.submit_solo_answer(uuid, uuid, text, uuid, integer, timestamptz) to service_role;
grant execute on function public.finish_solo_session(uuid, uuid, text) to service_role;
