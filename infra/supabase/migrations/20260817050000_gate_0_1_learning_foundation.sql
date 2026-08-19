-- Functional Gate 0-1 learning foundation.
-- Existing broad RLS/auth hardening is intentionally handled by the separate security hotfix.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.wib_business_date(p_timestamp timestamptz)
returns date
language sql
immutable
parallel safe
as $$
  select (p_timestamp at time zone 'Asia/Jakarta')::date;
$$;

create or replace function public.wib_week_start(p_timestamp timestamptz)
returns date
language sql
immutable
parallel safe
as $$
  select date_trunc('week', p_timestamp at time zone 'Asia/Jakarta')::date;
$$;

create or replace function public.wib_month_start(p_timestamp timestamptz)
returns date
language sql
immutable
parallel safe
as $$
  select date_trunc('month', p_timestamp at time zone 'Asia/Jakarta')::date;
$$;

create or replace function public.rank_tier(p_rank_points integer)
returns text
language sql
immutable
parallel safe
as $$
  select case
    when greatest(coalesce(p_rank_points, 0), 0) >= 1200 then 'legend'
    when greatest(coalesce(p_rank_points, 0), 0) >= 800 then 'elite'
    when greatest(coalesce(p_rank_points, 0), 0) >= 400 then 'warrior'
    else 'rookie'
  end;
$$;

create or replace function public.valid_question_options(p_options jsonb)
returns boolean
language sql
immutable
parallel safe
as $$
  select jsonb_typeof(p_options) = 'array'
    and jsonb_array_length(p_options) between 2 and 6
    and not exists (
      select 1
      from jsonb_array_elements(p_options) option_value
      where jsonb_typeof(option_value) <> 'string'
        or btrim(option_value #>> '{}') = ''
    );
$$;

alter table public.profiles
  add column if not exists draws integer not null default 0,
  add column if not exists current_streak integer not null default 0,
  add column if not exists best_streak integer not null default 0,
  add column if not exists last_streak_date date;

update public.profiles set target = 'cpns' where target not in ('cpns', 'bumn');
update public.practice_sessions set target = 'cpns' where target not in ('cpns', 'bumn');
update public.questions
set target = 'cpns', is_active = false
where target not in ('cpns', 'bumn');

alter table public.profiles drop constraint if exists profiles_target_check;
alter table public.profiles add constraint profiles_target_check check (target in ('cpns', 'bumn'));
alter table public.profiles drop constraint if exists profiles_non_negative_stats;
alter table public.profiles add constraint profiles_non_negative_stats check (
  rank_points >= 0 and total_matches >= 0 and wins >= 0 and losses >= 0 and draws >= 0
  and winrate >= 0 and winrate <= 100 and coins >= 0
  and current_streak >= 0 and best_streak >= current_streak
);

alter table public.practice_sessions drop constraint if exists practice_sessions_target_check;
alter table public.practice_sessions add constraint practice_sessions_target_check check (target in ('cpns', 'bumn'));
alter table public.practice_session_questions drop constraint if exists practice_session_questions_order_check;
alter table public.practice_session_questions add constraint practice_session_questions_order_check check (question_order between 1 and 5);

alter table public.questions
  add column if not exists source_key text,
  add column if not exists content_hash text;

update public.questions
set source_key = 'legacy-db:' || id::text
where source_key is null or btrim(source_key) = '';

update public.questions
set explanation = 'Jawaban yang benar adalah "' || coalesce(options ->> correct_option_index, '') || '".'
where explanation is null or btrim(explanation) = '';

alter table public.questions alter column source_key set not null;
alter table public.questions alter column explanation set not null;
alter table public.questions drop constraint if exists questions_correct_option_check;
alter table public.questions drop constraint if exists questions_options_array_check;
alter table public.questions drop constraint if exists questions_target_check;
alter table public.questions drop constraint if exists questions_weight_check;
alter table public.questions add constraint questions_options_array_check check (public.valid_question_options(options));
alter table public.questions add constraint questions_correct_option_check check (
  correct_option_index >= 0 and correct_option_index < jsonb_array_length(options)
);
alter table public.questions add constraint questions_target_check check (target in ('cpns', 'bumn'));
alter table public.questions add constraint questions_weight_check check (weight between 1 and 4);
alter table public.questions add constraint questions_explanation_check check (btrim(explanation) <> '');
create unique index if not exists questions_source_key_unique_idx on public.questions(source_key);

alter table public.practice_answers
  add column if not exists idempotency_key text,
  add column if not exists score_gained integer not null default 0,
  add column if not exists correct_option_index_snapshot integer,
  add column if not exists explanation_snapshot text;

alter table public.practice_answers drop constraint if exists practice_answers_option_check;
alter table public.practice_answers add constraint practice_answers_option_check check (
  selected_option_index is null or selected_option_index between 0 and 5
);
alter table public.practice_answers drop constraint if exists practice_answers_question_order_check;
alter table public.practice_answers add constraint practice_answers_question_order_check check (
  question_order is null or question_order between 1 and 5
);

alter table public.match_logs drop constraint if exists match_logs_selected_option_check;
alter table public.match_logs add constraint match_logs_selected_option_check check (
  selected_option_index is null or selected_option_index between 0 and 5
);

update public.practice_answers answer
set
  score_gained = case when answer.is_correct then question.weight * 10 else 0 end,
  correct_option_index_snapshot = question.correct_option_index,
  explanation_snapshot = question.explanation
from public.questions question
where question.id = answer.question_id
  and (answer.correct_option_index_snapshot is null or answer.explanation_snapshot is null);

alter table public.store_items drop constraint if exists store_items_type_check;
update public.store_items set is_active = false where type = 'arena';
alter table public.store_items add constraint store_items_type_check check (type in ('character_skin', 'tower', 'arena'));

alter table public.hired_pass_missions drop constraint if exists hired_pass_missions_event_type_check;
alter table public.hired_pass_missions add constraint hired_pass_missions_event_type_check check (
  event_type in (
    'practice_completed', 'public_pvp_completed', 'ranked_completed',
    'ranked_won', 'interview_completed', 'streak_day_created', 'battle_completed'
  )
);

create table if not exists public.api_idempotency_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  operation text not null,
  idempotency_key text not null,
  request_hash text not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  constraint api_idempotency_key_length_check check (char_length(idempotency_key) between 1 and 160),
  constraint api_idempotency_unique unique (user_id, operation, idempotency_key)
);

create table if not exists public.rank_point_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  applied_delta integer not null,
  requested_delta integer not null,
  source text not null,
  source_id text not null,
  idempotency_key text not null,
  balance_after integer not null,
  created_at timestamptz not null default now(),
  constraint rank_point_source_check check (source in ('ranked_result', 'daily_practice', 'daily_pvp', 'admin')),
  constraint rank_point_balance_check check (balance_after >= 0),
  constraint rank_point_idempotency_unique unique (user_id, idempotency_key)
);

create index if not exists rank_point_transactions_user_created_idx
  on public.rank_point_transactions(user_id, created_at desc);

create table if not exists public.daily_mission_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  mission_key text not null,
  business_date date not null,
  source_type text not null,
  source_id text not null,
  completed_at timestamptz not null,
  reward_rank_points integer not null,
  rank_transaction_id uuid not null references public.rank_point_transactions(id),
  primary key (user_id, mission_key, business_date),
  constraint daily_mission_key_check check (mission_key in ('daily_practice', 'daily_pvp')),
  constraint daily_mission_reward_check check (reward_rank_points in (50, 80))
);

create table if not exists public.daily_learning_activity (
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_date date not null,
  source_type text not null,
  source_id text not null,
  completed_at timestamptz not null,
  primary key (user_id, business_date)
);

create table if not exists public.practice_session_completions (
  session_id uuid primary key references public.practice_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  completed_at timestamptz not null,
  response jsonb not null,
  daily_mission_reward integer,
  rank_points_after integer not null,
  current_streak integer not null,
  best_streak integer not null,
  last_streak_date date not null,
  hired_pass_activity_applied boolean not null default false
);

alter table public.api_idempotency_records enable row level security;
alter table public.rank_point_transactions enable row level security;
alter table public.daily_mission_progress enable row level security;
alter table public.daily_learning_activity enable row level security;
alter table public.practice_session_completions enable row level security;

revoke all on public.api_idempotency_records, public.rank_point_transactions,
  public.daily_mission_progress, public.daily_learning_activity,
  public.practice_session_completions from public, anon, authenticated;
grant all on public.api_idempotency_records, public.rank_point_transactions,
  public.daily_mission_progress, public.daily_learning_activity,
  public.practice_session_completions to service_role;

drop trigger if exists practice_hired_pass_completion on public.practice_sessions;

create or replace function public.apply_daily_mission(
  p_user_id uuid,
  p_mission_key text,
  p_source_type text,
  p_source_id text,
  p_completed_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_date date := public.wib_business_date(p_completed_at);
  v_reward integer;
  v_transaction_id uuid;
  v_balance integer;
begin
  v_reward := case p_mission_key when 'daily_practice' then 50 when 'daily_pvp' then 80 else null end;
  if v_reward is null then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported daily mission';
  end if;

  perform 1 from public.profiles where id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;

  select rank_points into v_balance
  from public.profiles where id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;

  if exists (
    select 1 from public.daily_mission_progress
    where user_id = p_user_id and mission_key = p_mission_key and business_date = v_date
  ) then
    return jsonb_build_object(
      'key', p_mission_key, 'businessDate', v_date, 'awarded', false,
      'rewardRankPoints', 0, 'rankPoints', v_balance
    );
  end if;

  update public.profiles
  set rank_points = rank_points + v_reward, updated_at = p_completed_at
  where id = p_user_id
  returning rank_points into v_balance;

  insert into public.rank_point_transactions
    (user_id, applied_delta, requested_delta, source, source_id, idempotency_key, balance_after, created_at)
  values
    (p_user_id, v_reward, v_reward, p_mission_key, p_source_id,
     'daily:' || p_mission_key || ':' || v_date::text, v_balance, p_completed_at)
  returning id into v_transaction_id;

  insert into public.daily_mission_progress
    (user_id, mission_key, business_date, source_type, source_id, completed_at,
     reward_rank_points, rank_transaction_id)
  values
    (p_user_id, p_mission_key, v_date, p_source_type, p_source_id, p_completed_at,
     v_reward, v_transaction_id);

  return jsonb_build_object(
    'key', p_mission_key, 'businessDate', v_date, 'awarded', true,
    'rewardRankPoints', v_reward, 'rankPoints', v_balance
  );
end;
$$;

create or replace function public.get_leaderboard_page(
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with ordered as (
    select
      row_number() over (order by rank_points desc, wins desc, id asc) as rank,
      id, username, rank_points, wins, losses, draws, total_matches
    from public.profiles
  ), page as (
    select * from ordered
    order by rank
    limit greatest(1, least(coalesce(p_limit, 50), 100))
    offset greatest(coalesce(p_offset, 0), 0)
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'rank', rank,
        'userId', id,
        'username', username,
        'rankPoints', rank_points,
        'tier', public.rank_tier(rank_points),
        'rankedWins', wins,
        'totalMatches', total_matches,
        'rankedWinRate', case when wins + losses + draws = 0 then 0
          else round((wins::numeric / (wins + losses + draws)::numeric) * 100, 2) end
      ) order by rank) from page
    ), '[]'::jsonb),
    'total', (select count(*) from ordered)
  );
$$;

create or replace function public.get_user_leaderboard_rank(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with ordered as (
    select
      row_number() over (order by rank_points desc, wins desc, id asc) as rank,
      id, username, rank_points, wins, losses, draws, total_matches
    from public.profiles
  )
  select jsonb_build_object(
    'rank', rank,
    'userId', id,
    'username', username,
    'rankPoints', rank_points,
    'tier', public.rank_tier(rank_points),
    'rankedWins', wins,
    'totalMatches', total_matches,
    'rankedWinRate', case when wins + losses + draws = 0 then 0
      else round((wins::numeric / (wins + losses + draws)::numeric) * 100, 2) end
  )
  from ordered where id = p_user_id;
$$;

revoke all on function public.get_leaderboard_page(integer, integer) from public, anon, authenticated;
revoke all on function public.get_user_leaderboard_rank(uuid) from public, anon, authenticated;
grant execute on function public.get_leaderboard_page(integer, integer) to service_role;
grant execute on function public.get_user_leaderboard_rank(uuid) to service_role;

create or replace function public.apply_streak_activity(
  p_user_id uuid,
  p_source_type text,
  p_source_id text,
  p_completed_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_date date := public.wib_business_date(p_completed_at);
  v_inserted boolean := false;
  v_current integer;
  v_best integer;
  v_last date;
begin
  insert into public.daily_learning_activity
    (user_id, business_date, source_type, source_id, completed_at)
  values (p_user_id, v_date, p_source_type, p_source_id, p_completed_at)
  on conflict (user_id, business_date) do nothing;
  v_inserted := found;

  select current_streak, best_streak, last_streak_date
  into v_current, v_best, v_last
  from public.profiles where id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;

  if v_inserted and (v_last is null or v_date > v_last) then
    v_current := case when v_last = v_date - 1 then v_current + 1 else 1 end;
    v_best := greatest(v_best, v_current);
    v_last := v_date;
    update public.profiles
    set current_streak = v_current, best_streak = v_best,
        last_streak_date = v_last, updated_at = p_completed_at
    where id = p_user_id;
  end if;

  return jsonb_build_object(
    'created', v_inserted, 'current', v_current, 'best', v_best, 'lastDate', v_last
  );
end;
$$;

create or replace function public.create_practice_session(
  p_user_id uuid,
  p_category text default null,
  p_subcategory text default null
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
  v_question_ids uuid[];
  v_session_id uuid;
  v_questions jsonb;
begin
  if v_subcategory is not null and v_category is null then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: category is required with subcategory';
  end if;
  select target into v_target from public.profiles where id = p_user_id;
  if v_target is null then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;

  if v_category is not null and not exists (
    select 1 from public.questions
    where target = v_target and category = v_category and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: category is unavailable';
  end if;
  if v_subcategory is not null and not exists (
    select 1 from public.questions
    where target = v_target and category = v_category and subcategory = v_subcategory and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: subcategory is unavailable';
  end if;

  select array_agg(id) into v_question_ids
  from (
    select id from public.questions
    where target = v_target and is_active
      and (v_category is null or category = v_category)
      and (v_subcategory is null or subcategory = v_subcategory)
    order by random()
    limit 5
  ) selected;
  if coalesce(array_length(v_question_ids, 1), 0) <> 5 then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: at least five active questions are required';
  end if;

  insert into public.practice_sessions
    (user_id, target, category, subcategory, total_questions)
  values (p_user_id, v_target, v_category, v_subcategory, 5)
  returning id into v_session_id;

  insert into public.practice_session_questions(session_id, question_id, question_order)
  select v_session_id, question_id, ordinal::integer
  from unnest(v_question_ids) with ordinality locked(question_id, ordinal);

  select jsonb_agg(jsonb_build_object(
    'sessionQuestionId', locked.id,
    'questionId', question.id,
    'questionOrder', locked.question_order,
    'target', question.target,
    'category', question.category,
    'subcategory', question.subcategory,
    'prompt', question.prompt,
    'options', question.options,
    'difficulty', question.difficulty,
    'weight', question.weight,
    'effect', question.effect,
    'damageValue', question.damage_value,
    'healValue', question.heal_value,
    'timeLimitSeconds', question.time_limit_seconds,
    'hint', question.hint
  ) order by locked.question_order)
  into v_questions
  from public.practice_session_questions locked
  join public.questions question on question.id = locked.question_id
  where locked.session_id = v_session_id;

  return jsonb_build_object(
    'sessionId', v_session_id, 'target', v_target, 'category', v_category,
    'subcategory', v_subcategory, 'totalQuestions', 5, 'questions', v_questions
  );
end;
$$;

create or replace function public.submit_practice_answer(
  p_user_id uuid,
  p_session_id uuid,
  p_idempotency_key text,
  p_session_question_id uuid,
  p_selected_option_index integer,
  p_response_time_ms integer default null,
  p_used_hint boolean default false,
  p_answered_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.practice_sessions%rowtype;
  v_question public.questions%rowtype;
  v_question_order integer;
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_is_correct boolean;
  v_score integer;
  v_answered integer;
  v_correct integer;
  v_total_score integer;
  v_accuracy numeric(5,2);
  v_response jsonb;
  v_question_id uuid;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey must contain 1..160 characters';
  end if;
  if p_response_time_ms is not null and p_response_time_ms < 0 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: responseTimeMs';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object(
    'sessionId', p_session_id, 'sessionQuestionId', p_session_question_id,
    'selectedOptionIndex', p_selected_option_index,
    'responseTimeMs', p_response_time_ms, 'usedHint', p_used_hint
  )::text, 'sha256'), 'hex');

  perform pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':practice.answer:' || p_idempotency_key, 0
  ));

  select * into v_session from public.practice_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: practice session';
  end if;

  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'practice.answer'
    and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_record.response;
  end if;
  if v_session.finished_at is not null then
    raise exception using errcode = 'P0001', message = 'CONFLICT: practice session already finished';
  end if;

  select locked.question_id, locked.question_order
  into v_question_id, v_question_order
  from public.practice_session_questions locked
  where locked.id = p_session_question_id and locked.session_id = p_session_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: practice question';
  end if;

  select * into v_question from public.questions where id = v_question_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: question';
  end if;
  if p_selected_option_index < 0 or p_selected_option_index >= jsonb_array_length(v_question.options) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: selectedOptionIndex';
  end if;
  if exists (select 1 from public.practice_answers where session_question_id = p_session_question_id) then
    raise exception using errcode = 'P0001', message = 'CONFLICT: practice question already answered';
  end if;

  v_is_correct := p_selected_option_index = v_question.correct_option_index;
  v_score := case when v_is_correct then v_question.weight * 10 else 0 end;
  insert into public.practice_answers
    (session_id, user_id, session_question_id, question_id, question_order,
     selected_option_index, is_correct, used_hint, response_time_ms, answered_at,
     idempotency_key, score_gained, correct_option_index_snapshot, explanation_snapshot)
  values
    (p_session_id, p_user_id, p_session_question_id, v_question.id, v_question_order,
     p_selected_option_index, v_is_correct, p_used_hint, p_response_time_ms, p_answered_at,
     p_idempotency_key, v_score, v_question.correct_option_index, v_question.explanation);

  select count(*), count(*) filter (where is_correct), coalesce(sum(score_gained), 0)
  into v_answered, v_correct, v_total_score
  from public.practice_answers where session_id = p_session_id and user_id = p_user_id;
  v_accuracy := round((v_correct::numeric / v_answered::numeric) * 100, 2);
  update public.practice_sessions
  set correct_count = v_correct, total_score = v_total_score, accuracy = v_accuracy
  where id = p_session_id;

  if v_answered = 5 then
    perform public.complete_practice_session(p_user_id, p_session_id, p_answered_at);
  end if;

  v_response := jsonb_build_object(
    'sessionId', p_session_id,
    'sessionQuestionId', p_session_question_id,
    'questionId', v_question.id,
    'selectedOptionIndex', p_selected_option_index,
    'isCorrect', v_is_correct,
    'correctOptionIndex', v_question.correct_option_index,
    'explanation', v_question.explanation,
    'scoreGained', v_score,
    'progress', jsonb_build_object(
      'answeredCount', v_answered, 'totalQuestions', 5,
      'correctCount', v_correct, 'wrongCount', v_answered - v_correct,
      'unansweredCount', 5 - v_answered, 'accuracy', v_accuracy,
      'totalScore', v_total_score, 'isFinished', v_answered = 5
    )
  );

  insert into public.api_idempotency_records
    (user_id, operation, idempotency_key, request_hash, response)
  values (p_user_id, 'practice.answer', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

create or replace function public.finish_practice_session(
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
  v_hash text;
  v_record public.api_idempotency_records%rowtype;
  v_response jsonb;
begin
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 160 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: idempotencyKey must contain 1..160 characters';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':practice.finish:' || p_idempotency_key, 0
  ));
  perform 1 from public.practice_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: practice session';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_object('sessionId', p_session_id)::text, 'sha256'), 'hex');
  select * into v_record from public.api_idempotency_records
  where user_id = p_user_id and operation = 'practice.finish'
    and idempotency_key = p_idempotency_key;
  if found then
    if v_record.request_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_record.response;
  end if;
  v_response := public.complete_practice_session(p_user_id, p_session_id, p_completed_at);
  insert into public.api_idempotency_records
    (user_id, operation, idempotency_key, request_hash, response)
  values (p_user_id, 'practice.finish', p_idempotency_key, v_hash, v_response);
  return v_response;
end;
$$;

revoke all on function public.apply_daily_mission(uuid, text, text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.apply_streak_activity(uuid, text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.create_practice_session(uuid, text, text) from public, anon, authenticated;
revoke all on function public.submit_practice_answer(uuid, uuid, text, uuid, integer, integer, boolean, timestamptz) from public, anon, authenticated;
revoke all on function public.finish_practice_session(uuid, uuid, text, timestamptz) from public, anon, authenticated;
grant execute on function public.apply_daily_mission(uuid, text, text, text, timestamptz) to service_role;
grant execute on function public.apply_streak_activity(uuid, text, text, timestamptz) to service_role;
grant execute on function public.create_practice_session(uuid, text, text) to service_role;
grant execute on function public.submit_practice_answer(uuid, uuid, text, uuid, integer, integer, boolean, timestamptz) to service_role;
grant execute on function public.finish_practice_session(uuid, uuid, text, timestamptz) to service_role;

create or replace function public.record_hired_pass_activity(
  p_user_id uuid,
  p_event_type text,
  p_source_id text,
  p_occurred_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mission public.hired_pass_missions%rowtype;
  v_period_start date;
  v_event_id uuid;
  v_progress_count integer;
  v_awarded_at timestamptz;
  v_points_awarded integer := 0;
  v_season_id text;
  v_total_points integer := 0;
begin
  if p_event_type not in (
    'practice_completed', 'public_pvp_completed', 'ranked_completed',
    'ranked_won', 'interview_completed', 'streak_day_created', 'battle_completed'
  ) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported Hired Pass event type';
  end if;
  if nullif(btrim(p_source_id), '') is null then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: Hired Pass source ID is required';
  end if;

  for v_mission in
    select mission.*
    from public.hired_pass_missions mission
    join public.hired_pass_seasons season on season.id = mission.season_id
    where mission.event_type = p_event_type
      and mission.is_active and season.is_active
      and p_occurred_at >= season.starts_at and p_occurred_at < season.ends_at
  loop
    v_season_id := v_mission.season_id;
    v_event_id := null;
    v_period_start := case v_mission.cadence
      when 'daily' then public.wib_business_date(p_occurred_at)
      when 'weekly' then public.wib_week_start(p_occurred_at)
      else (
        select public.wib_business_date(starts_at)
        from public.hired_pass_seasons where id = v_mission.season_id
      )
    end;

    insert into public.hired_pass_activity_events
      (user_id, mission_id, source_type, source_id, period_start)
    values (p_user_id, v_mission.id, p_event_type, p_source_id, v_period_start)
    on conflict (user_id, mission_id, source_type, source_id) do nothing
    returning id into v_event_id;
    if v_event_id is null then continue; end if;

    insert into public.user_hired_pass_progress(user_id, season_id)
    values (p_user_id, v_mission.season_id)
    on conflict (user_id, season_id) do nothing;

    insert into public.user_hired_pass_mission_progress
      (user_id, mission_id, period_start, progress_count, updated_at)
    values (p_user_id, v_mission.id, v_period_start, 1, p_occurred_at)
    on conflict (user_id, mission_id, period_start) do update set
      progress_count = least(v_mission.target_count,
        public.user_hired_pass_mission_progress.progress_count + 1),
      updated_at = p_occurred_at
    returning progress_count, points_awarded_at into v_progress_count, v_awarded_at;

    if v_progress_count >= v_mission.target_count and v_awarded_at is null then
      update public.user_hired_pass_mission_progress
      set completed_at = coalesce(completed_at, p_occurred_at),
          points_awarded_at = p_occurred_at, updated_at = p_occurred_at
      where user_id = p_user_id and mission_id = v_mission.id
        and period_start = v_period_start and points_awarded_at is null
      returning points_awarded_at into v_awarded_at;
      if found then
        update public.user_hired_pass_progress
        set pass_points = pass_points + v_mission.points_reward, updated_at = p_occurred_at
        where user_id = p_user_id and season_id = v_mission.season_id;
        v_points_awarded := v_points_awarded + v_mission.points_reward;
      end if;
    end if;
  end loop;

  if v_season_id is not null then
    select pass_points into v_total_points from public.user_hired_pass_progress
    where user_id = p_user_id and season_id = v_season_id;
  end if;
  return jsonb_build_object(
    'seasonId', v_season_id, 'pointsAwarded', v_points_awarded,
    'passPoints', coalesce(v_total_points, 0)
  );
end;
$$;


create or replace function public.finalize_match_result(
  p_room_id text,
  p_mode text,
  p_target text,
  p_player_a_id uuid,
  p_player_b_id uuid,
  p_winner_user_id uuid,
  p_loser_user_id uuid,
  p_outcome text,
  p_reason text,
  p_player_a_hp integer,
  p_player_b_hp integer,
  p_player_a_points integer,
  p_player_b_points integer,
  p_duration_seconds integer default null,
  p_started_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.match_results%rowtype;
  v_is_bot boolean := p_mode = 'bot';
  v_ranked_progression boolean;
  v_normal_public boolean;
  v_requested_rating_a integer := 0;
  v_requested_rating_b integer := 0;
  v_rating_delta_a integer := 0;
  v_rating_delta_b integer := 0;
  v_coins_delta_a integer := 0;
  v_coins_delta_b integer := 0;
  v_rank_before integer;
  v_rank_after integer;
  v_coin_balance integer;
  v_daily_a jsonb;
  v_daily_b jsonb;
  v_streak_a jsonb;
  v_streak_b jsonb;
  v_completed_at timestamptz := clock_timestamp();
begin
  if p_mode not in ('ranked', 'casual', 'bot') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported match mode';
  end if;
  if p_target not in ('cpns', 'bumn') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported battle target';
  end if;
  if p_outcome not in ('player_a_win', 'player_b_win', 'draw') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported match outcome';
  end if;

  v_ranked_progression := p_mode = 'ranked' and not (
    p_reason = 'disconnect' and p_winner_user_id is null and p_loser_user_id is null
  );
  v_normal_public := p_mode in ('ranked', 'casual')
    and p_reason in ('hp_zero', 'round_timeout', 'question_exhaustion', 'draw');

  if v_ranked_progression then
    if p_outcome = 'player_a_win' then
      v_requested_rating_a := 20; v_requested_rating_b := -12;
      v_coins_delta_a := 10; v_coins_delta_b := 3;
    elsif p_outcome = 'player_b_win' then
      v_requested_rating_a := -12; v_requested_rating_b := 20;
      v_coins_delta_a := 3; v_coins_delta_b := 10;
    else
      v_coins_delta_a := 5; v_coins_delta_b := 5;
    end if;
  end if;

  insert into public.match_results(
    room_id, mode, target, player_a_id, player_b_id, winner_user_id,
    loser_user_id, outcome, reason, player_a_hp, player_b_hp,
    player_a_points, player_b_points, rating_delta_a, rating_delta_b,
    coins_delta_a, coins_delta_b, duration_seconds, started_at, ended_at
  ) values (
    p_room_id, p_mode, p_target, p_player_a_id,
    case when v_is_bot then null else p_player_b_id end,
    p_winner_user_id, p_loser_user_id, p_outcome, p_reason,
    p_player_a_hp, p_player_b_hp, p_player_a_points, p_player_b_points,
    v_requested_rating_a, v_requested_rating_b, v_coins_delta_a,
    case when v_is_bot then 0 else v_coins_delta_b end,
    p_duration_seconds, p_started_at, v_completed_at
  ) on conflict (room_id) do nothing returning * into v_result;

  if v_result.id is null then
    select * into v_result from public.match_results where room_id = p_room_id;
    return jsonb_build_object(
      'persisted', false, 'reason', 'duplicate', 'matchResultId', v_result.id,
      'ratingDeltaA', v_result.rating_delta_a, 'ratingDeltaB', v_result.rating_delta_b,
      'coinsDeltaA', v_result.coins_delta_a, 'coinsDeltaB', v_result.coins_delta_b,
      'progressionApplied', v_result.mode = 'ranked' or (
        v_result.mode = 'casual' and v_result.reason in ('hp_zero', 'round_timeout', 'question_exhaustion', 'draw')
      )
    );
  end if;

  if v_ranked_progression then
    select rank_points into v_rank_before from public.profiles
    where id = p_player_a_id for update;
    if not found then raise exception using message = 'NOT_FOUND: player A profile'; end if;
    v_rank_after := greatest(0, v_rank_before + v_requested_rating_a);
    v_rating_delta_a := v_rank_after - v_rank_before;
    update public.profiles set
      rank_points = v_rank_after,
      total_matches = total_matches + 1,
      wins = wins + case when p_winner_user_id = p_player_a_id then 1 else 0 end,
      losses = losses + case when p_loser_user_id = p_player_a_id then 1 else 0 end,
      draws = draws + case when p_outcome = 'draw' then 1 else 0 end,
      winrate = round((wins + case when p_winner_user_id = p_player_a_id then 1 else 0 end)::numeric
        / (total_matches + 1)::numeric * 100, 2),
      coins = coins + v_coins_delta_a,
      updated_at = v_completed_at
    where id = p_player_a_id returning coins into v_coin_balance;
    insert into public.rank_point_transactions
      (user_id, applied_delta, requested_delta, source, source_id, idempotency_key, balance_after, created_at)
    values (p_player_a_id, v_rating_delta_a, v_requested_rating_a, 'ranked_result', p_room_id,
      'ranked:' || p_room_id || ':player-a', v_rank_after, v_completed_at);
    if v_coins_delta_a <> 0 then
      insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
      values (p_player_a_id, v_coins_delta_a, 'match_reward', p_room_id,
        'match:' || p_room_id || ':player-a', v_coin_balance);
    end if;

    if not v_is_bot and p_player_b_id is not null then
      select rank_points into v_rank_before from public.profiles
      where id = p_player_b_id for update;
      if not found then raise exception using message = 'NOT_FOUND: player B profile'; end if;
      v_rank_after := greatest(0, v_rank_before + v_requested_rating_b);
      v_rating_delta_b := v_rank_after - v_rank_before;
      update public.profiles set
        rank_points = v_rank_after,
        total_matches = total_matches + 1,
        wins = wins + case when p_winner_user_id = p_player_b_id then 1 else 0 end,
        losses = losses + case when p_loser_user_id = p_player_b_id then 1 else 0 end,
        draws = draws + case when p_outcome = 'draw' then 1 else 0 end,
        winrate = round((wins + case when p_winner_user_id = p_player_b_id then 1 else 0 end)::numeric
          / (total_matches + 1)::numeric * 100, 2),
        coins = coins + v_coins_delta_b,
        updated_at = v_completed_at
      where id = p_player_b_id returning coins into v_coin_balance;
      insert into public.rank_point_transactions
        (user_id, applied_delta, requested_delta, source, source_id, idempotency_key, balance_after, created_at)
      values (p_player_b_id, v_rating_delta_b, v_requested_rating_b, 'ranked_result', p_room_id,
        'ranked:' || p_room_id || ':player-b', v_rank_after, v_completed_at);
      if v_coins_delta_b <> 0 then
        insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after)
        values (p_player_b_id, v_coins_delta_b, 'match_reward', p_room_id,
          'match:' || p_room_id || ':player-b', v_coin_balance);
      end if;
    end if;
  end if;

  if v_normal_public then
    v_daily_a := public.apply_daily_mission(p_player_a_id, 'daily_pvp', p_mode, p_room_id, v_completed_at);
    v_streak_a := public.apply_streak_activity(p_player_a_id, p_mode, p_room_id, v_completed_at);
    perform public.record_hired_pass_activity(p_player_a_id, 'public_pvp_completed', p_room_id, v_completed_at);
    if p_mode = 'ranked' then
      perform public.record_hired_pass_activity(p_player_a_id, 'ranked_completed', p_room_id, v_completed_at);
      if p_winner_user_id = p_player_a_id then
        perform public.record_hired_pass_activity(p_player_a_id, 'ranked_won', p_room_id, v_completed_at);
      end if;
    end if;
    if (v_streak_a ->> 'created')::boolean then
      perform public.record_hired_pass_activity(p_player_a_id, 'streak_day_created', p_room_id, v_completed_at);
    end if;

    if p_player_b_id is not null then
      v_daily_b := public.apply_daily_mission(p_player_b_id, 'daily_pvp', p_mode, p_room_id, v_completed_at);
      v_streak_b := public.apply_streak_activity(p_player_b_id, p_mode, p_room_id, v_completed_at);
      perform public.record_hired_pass_activity(p_player_b_id, 'public_pvp_completed', p_room_id, v_completed_at);
      if p_mode = 'ranked' then
        perform public.record_hired_pass_activity(p_player_b_id, 'ranked_completed', p_room_id, v_completed_at);
        if p_winner_user_id = p_player_b_id then
          perform public.record_hired_pass_activity(p_player_b_id, 'ranked_won', p_room_id, v_completed_at);
        end if;
      end if;
      if (v_streak_b ->> 'created')::boolean then
        perform public.record_hired_pass_activity(p_player_b_id, 'streak_day_created', p_room_id, v_completed_at);
      end if;
    end if;
  end if;

  update public.match_results
  set rating_delta_a = v_rating_delta_a, rating_delta_b = v_rating_delta_b
  where id = v_result.id;

  return jsonb_build_object(
    'persisted', true, 'matchResultId', v_result.id,
    'ratingDeltaA', v_rating_delta_a, 'ratingDeltaB', v_rating_delta_b,
    'coinsDeltaA', v_coins_delta_a,
    'coinsDeltaB', case when v_is_bot then 0 else v_coins_delta_b end,
    'progressionApplied', v_ranked_progression or v_normal_public,
    'dailyMissionA', v_daily_a, 'dailyMissionB', v_daily_b,
    'streakA', v_streak_a, 'streakB', v_streak_b
  );
end;
$$;

-- A Practice completion creates a streak-day Pass event only when the date was new.
create or replace function public.complete_practice_session(
  p_user_id uuid,
  p_session_id uuid,
  p_completed_at timestamptz default clock_timestamp()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.practice_sessions%rowtype;
  v_existing jsonb;
  v_answered integer;
  v_correct integer;
  v_score integer;
  v_accuracy numeric(5,2);
  v_mission jsonb;
  v_streak jsonb;
  v_pass jsonb;
  v_response jsonb;
  v_rank_points integer;
begin
  select * into v_session from public.practice_sessions
  where id = p_session_id and user_id = p_user_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND: practice session'; end if;
  select response into v_existing from public.practice_session_completions where session_id = p_session_id;
  if v_existing is not null then return v_existing; end if;
  select count(*), count(*) filter (where is_correct), coalesce(sum(score_gained), 0)
  into v_answered, v_correct, v_score from public.practice_answers
  where session_id = p_session_id and user_id = p_user_id;
  if v_answered <> v_session.total_questions or v_session.total_questions <> 5 then
    raise exception using errcode = 'P0001', message = 'ACTION_REJECTED: five answers are required';
  end if;
  v_accuracy := round((v_correct::numeric / v_answered::numeric) * 100, 2);
  update public.practice_sessions set correct_count = v_correct, total_score = v_score,
    accuracy = v_accuracy, finished_at = coalesce(finished_at, p_completed_at)
  where id = p_session_id;
  v_mission := public.apply_daily_mission(p_user_id, 'daily_practice', 'practice', p_session_id::text, p_completed_at);
  v_streak := public.apply_streak_activity(p_user_id, 'practice', p_session_id::text, p_completed_at);
  v_pass := public.record_hired_pass_activity(p_user_id, 'practice_completed', p_session_id::text, p_completed_at);
  if (v_streak ->> 'created')::boolean then
    perform public.record_hired_pass_activity(p_user_id, 'streak_day_created', p_session_id::text, p_completed_at);
  end if;
  select rank_points into v_rank_points from public.profiles where id = p_user_id;
  v_response := jsonb_build_object(
    'sessionId', p_session_id, 'target', v_session.target, 'category', v_session.category,
    'subcategory', v_session.subcategory, 'totalQuestions', 5, 'answeredCount', v_answered,
    'correctCount', v_correct, 'wrongCount', v_answered - v_correct, 'unansweredCount', 0,
    'accuracy', v_accuracy, 'totalScore', v_score, 'startedAt', v_session.started_at,
    'finishedAt', coalesce(v_session.finished_at, p_completed_at),
    'missionReward', v_mission, 'streak', v_streak, 'hiredPass', v_pass
  );
  insert into public.practice_session_completions(
    session_id, user_id, completed_at, response, daily_mission_reward,
    rank_points_after, current_streak, best_streak, last_streak_date,
    hired_pass_activity_applied
  ) values (
    p_session_id, p_user_id, p_completed_at, v_response,
    nullif((v_mission ->> 'rewardRankPoints')::integer, 0), v_rank_points,
    (v_streak ->> 'current')::integer, (v_streak ->> 'best')::integer,
    (v_streak ->> 'lastDate')::date, true
  );
  return v_response;
end;
$$;

revoke all on function public.complete_practice_session(uuid, uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.complete_practice_session(uuid, uuid, timestamptz) to service_role;
