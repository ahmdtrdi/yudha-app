-- =========================================================
-- YUDHA Supabase Bootstrap Schema (Unified & Synchronized)
-- =========================================================

create extension if not exists "pgcrypto";

-- =========================================================
-- TRIGGER FUNCTION UTILITY
-- =========================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- 1. PROFILES
-- =========================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  full_name text,
  target text not null default 'cpns',
  rank_points integer not null default 1000,
  total_matches integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  winrate numeric(5, 2) not null default 0,
  coins integer not null default 0,
  equipped_avatar_id uuid,
  equipped_arena_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_non_negative_stats check (
    rank_points >= 0
    and total_matches >= 0
    and wins >= 0
    and losses >= 0
    and winrate >= 0
    and winrate <= 100
    and coins >= 0
  ),
  constraint profiles_target_check check (
    target in ('cpns', 'bumn', 'kedinasan')
  )
);

-- =========================================================
-- 2. QUESTIONS (Gamified Loop)
-- =========================================================
create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  target text not null default 'cpns',
  category text not null,
  subcategory text,
  prompt text not null,
  options jsonb not null,
  correct_option_index integer not null,
  explanation text,
  difficulty text not null default 'easy',
  weight integer not null default 1,
  effect text not null default 'damage',
  damage_value integer not null default 10,
  heal_value integer not null default 0,
  time_limit_seconds integer not null default 30,
  hint text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint questions_difficulty_check check (difficulty in ('easy', 'medium', 'hard')),
  constraint questions_effect_check check (effect in ('damage', 'heal')),
  constraint questions_target_check check (target in ('cpns', 'bumn', 'kedinasan')),
  constraint questions_options_array_check check (
    jsonb_typeof(options) = 'array'
    and jsonb_array_length(options) = 4
  ),
  constraint questions_correct_option_check check (correct_option_index between 0 and 3),
  constraint questions_weight_check check (weight between 1 and 3),
  constraint questions_values_check check (
    damage_value >= 0
    and heal_value >= 0
    and time_limit_seconds > 0
  )
);

-- =========================================================
-- 3. SAFE PUBLIC QUESTIONS VIEW
-- =========================================================
create or replace view public.public_questions as
select
  id,
  target,
  category,
  subcategory,
  prompt,
  options,
  difficulty,
  weight,
  effect,
  damage_value,
  heal_value,
  time_limit_seconds,
  hint,
  created_at,
  updated_at
from public.questions
where is_active = true;

-- =========================================================
-- 4. PRACTICE SESSIONS
-- =========================================================
create table if not exists public.practice_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null default 'cpns',
  category text,
  subcategory text,
  total_questions integer not null default 0,
  correct_count integer not null default 0,
  total_score integer not null default 0,
  accuracy numeric(5, 2) not null default 0,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  constraint practice_sessions_counts_check check (
    total_questions >= 0
    and correct_count >= 0
    and correct_count <= total_questions
    and total_score >= 0
    and accuracy >= 0
    and accuracy <= 100
  ),
  constraint practice_sessions_target_check check (
    target in ('cpns', 'bumn', 'kedinasan')
  )
);

create table if not exists public.practice_session_questions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.practice_sessions(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  question_order integer not null,
  created_at timestamptz not null default now(),
  constraint practice_session_questions_order_check
    check (question_order between 1 and 5),
  constraint practice_session_questions_unique_order
    unique (session_id, question_order),
  constraint practice_session_questions_unique_question
    unique (session_id, question_id)
);

-- =========================================================
-- 5. PRACTICE ANSWERS
-- =========================================================
create table if not exists public.practice_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.practice_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_question_id uuid references public.practice_session_questions(id) on delete cascade,
  question_id uuid references public.questions(id) on delete set null,
  question_order integer,
  selected_option_index integer,
  player_answer text,
  is_correct boolean not null default false,
  used_hint boolean not null default false,
  response_time_ms integer,
  answered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint practice_answers_option_check check (
    selected_option_index is null
    or selected_option_index between 0 and 3
  ),
  constraint practice_answers_response_time_check check (
    response_time_ms is null
    or response_time_ms >= 0
  ),
  constraint practice_answers_question_order_check check (
    question_order is null
    or question_order >= 1
  )
);

-- =========================================================
-- 6. MATCH RESULTS (PvP System)
-- =========================================================
create table if not exists public.match_results (
  id uuid primary key default gen_random_uuid(),
  room_id text not null unique,
  mode text not null default 'player',
  player_a_id uuid references public.profiles(id) on delete set null,
  player_b_id uuid references public.profiles(id) on delete set null,
  winner_user_id uuid references public.profiles(id) on delete set null,
  loser_user_id uuid references public.profiles(id) on delete set null,
  outcome text not null,
  reason text not null,
  player_a_hp integer not null,
  player_b_hp integer not null,
  player_a_points integer not null,
  player_b_points integer not null,
  rating_delta_a integer not null default 0,
  rating_delta_b integer not null default 0,
  coins_delta_a integer not null default 0,
  coins_delta_b integer not null default 0,
  duration_seconds integer,
  started_at timestamptz,
  ended_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint match_results_mode_check check (mode in ('player', 'bot')),
  constraint match_results_outcome_check check (outcome in ('player_a_win', 'player_b_win', 'draw')),
  constraint match_results_reason_check
    check (reason in ('hp_zero', 'surrender', 'question_exhaustion', 'draw', 'disconnect')),
  constraint match_results_winner_is_player_check check (
    winner_user_id is null
    or winner_user_id = player_a_id
    or winner_user_id = player_b_id
  ),
  constraint match_results_loser_is_player_check check (
    loser_user_id is null
    or loser_user_id = player_a_id
    or loser_user_id = player_b_id
  ),
  constraint match_results_winner_loser_different_check check (
    winner_user_id is null
    or loser_user_id is null
    or winner_user_id <> loser_user_id
  ),
  constraint match_results_hp_check check (
    player_a_hp between 0 and 100
    and player_b_hp between 0 and 100
  ),
  constraint match_results_points_check check (
    player_a_points >= 0
    and player_b_points >= 0
  ),
  constraint match_results_duration_check check (
    duration_seconds is null
    or duration_seconds >= 0
  )
);

-- =========================================================
-- 7. MATCH QUESTION POOL
-- =========================================================
create table if not exists public.match_question_pool (
  id uuid primary key default gen_random_uuid(),
  match_result_id uuid not null references public.match_results(id) on delete cascade,
  question_id uuid references public.questions(id) on delete set null,
  card_order integer not null,
  card_id text,
  effect text not null,
  weight integer not null default 1,
  damage_value integer not null default 0,
  heal_value integer not null default 0,
  created_at timestamptz not null default now(),
  constraint match_question_pool_effect_check check (effect in ('damage', 'heal')),
  constraint match_question_pool_order_check check (card_order >= 0),
  constraint match_question_pool_values_check check (
    weight >= 1
    and damage_value >= 0
    and heal_value >= 0
  )
);

-- =========================================================
-- 8. MATCH LOGS
-- =========================================================
create table if not exists public.match_logs (
  id uuid primary key default gen_random_uuid(),
  match_result_id uuid not null references public.match_results(id) on delete cascade,
  player_id uuid references public.profiles(id) on delete set null,
  question_id uuid references public.questions(id) on delete set null,
  card_id text,
  action_type text not null default 'play_card',
  selected_option_index integer,
  player_answer text,
  is_correct boolean,
  effect text not null default 'none',
  effect_value integer not null default 0,
  hp_before integer,
  hp_after integer,
  opponent_hp_before integer,
  opponent_hp_after integer,
  points_before integer,
  points_after integer,
  response_time_ms integer,
  action_timestamp timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint match_logs_action_type_check check (action_type in ('open_card', 'play_card', 'surrender', 'timeout')),
  constraint match_logs_selected_option_check check (
    selected_option_index is null
    or selected_option_index between 0 and 3
  ),
  constraint match_logs_effect_check check (effect in ('damage', 'heal', 'none')),
  constraint match_logs_effect_value_check check (effect_value >= 0),
  constraint match_logs_hp_check check (
    (hp_before is null or hp_before between 0 and 100)
    and (hp_after is null or hp_after between 0 and 100)
    and (opponent_hp_before is null or opponent_hp_before between 0 and 100)
    and (opponent_hp_after is null or opponent_hp_after between 0 and 100)
  ),
  constraint match_logs_points_check check (
    (points_before is null or points_before >= 0)
    and (points_after is null or points_after >= 0)
  ),
  constraint match_logs_response_time_check check (
    response_time_ms is null
    or response_time_ms >= 0
  )
);

-- =========================================================
-- 9. COMPANY CONTEXT DATA (Normalized No-RAG Configuration)
-- =========================================================
create table if not exists public.interview_company_profiles (
  id text primary key,
  name text not null,
  summary text not null,
  content_version text not null default 'v1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.interview_company_contexts (
  id uuid primary key default gen_random_uuid(),
  company_id text not null references public.interview_company_profiles(id) on delete cascade,
  category text not null,
  content text not null,
  priority integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- 10. AI INTERVIEW STATE LOOP (Engineer's Schema)
-- =========================================================
create table if not exists public.interview_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id text not null references public.interview_company_profiles(id),
  target_role text not null,
  mode text not null,
  language text not null default 'id',
  response_style text not null default 'text',
  status text not null default 'active'
    check (status in ('active', 'completed', 'failed')),
  context_snapshot jsonb not null,
  rolling_summary text not null default '',
  final_summary jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.interview_turns (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.interview_sessions(id) on delete cascade,
  role text not null check (role in ('question', 'answer')),
  content text not null,
  idempotency_key text,
  parent_turn_id uuid references public.interview_turns(id) on delete set null,
  processing_status text check (processing_status in ('pending', 'completed', 'failed')),
  evaluation jsonb,
  created_at timestamptz not null default now()
);

-- =========================================================
-- INDEX CONSOLIDATION BLOCK
-- =========================================================
create index if not exists profiles_rank_points_idx on public.profiles (rank_points desc);
create index if not exists questions_active_category_idx on public.questions (is_active, category);
create index if not exists questions_active_target_category_subcategory_idx on public.questions (is_active, target, category, subcategory);
create index if not exists practice_sessions_user_started_idx on public.practice_sessions (user_id, started_at desc);
create index if not exists practice_sessions_user_target_category_started_idx on public.practice_sessions (user_id, target, category, subcategory, started_at desc);
create index if not exists practice_answers_user_created_idx on public.practice_answers (user_id, created_at desc);
create index if not exists practice_answers_session_order_idx on public.practice_answers (session_id, question_order);
create index if not exists practice_session_questions_session_order_idx on public.practice_session_questions (session_id, question_order);
create unique index if not exists practice_answers_session_question_unique_idx on public.practice_answers (session_question_id) where session_question_id is not null;
create index if not exists match_results_player_a_idx on public.match_results (player_a_id, created_at desc);
create index if not exists match_results_player_b_idx on public.match_results (player_b_id, created_at desc);
create index if not exists match_results_winner_idx on public.match_results (winner_user_id, created_at desc);
create index if not exists match_question_pool_match_order_idx on public.match_question_pool (match_result_id, card_order);
create index if not exists match_logs_match_timestamp_idx on public.match_logs (match_result_id, action_timestamp);
create index if not exists match_logs_player_timestamp_idx on public.match_logs (player_id, action_timestamp desc);

-- Aligned Interview Context & Session Indices
create index if not exists interview_company_contexts_company_priority_idx on public.interview_company_contexts (company_id, priority asc);
create index if not exists interview_sessions_user_created_idx on public.interview_sessions (user_id, created_at desc);
create index if not exists interview_turns_session_created_idx on public.interview_turns (session_id, created_at asc);

-- Engineer's Partial State Rules Indices
create unique index if not exists interview_turns_session_idempotency_idx on public.interview_turns (session_id, idempotency_key) where idempotency_key is not null;
create unique index if not exists interview_turns_session_pending_answer_idx on public.interview_turns (session_id) where role = 'answer' and processing_status = 'pending';
create unique index if not exists interview_turns_parent_question_idx on public.interview_turns (parent_turn_id) where role = 'question' and parent_turn_id is not null;

-- =========================================================
-- TRIGGER DECLARATIONS (Pointing to Unified Utility Function)
-- =========================================================
drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();

drop trigger if exists set_questions_updated_at on public.questions;
create trigger set_questions_updated_at before update on public.questions for each row execute function public.set_updated_at();

drop trigger if exists interview_company_profiles_updated_at on public.interview_company_profiles;
create trigger interview_company_profiles_updated_at before update on public.interview_company_profiles for each row execute function public.set_updated_at();

drop trigger if exists interview_company_contexts_updated_at on public.interview_company_contexts;
create trigger interview_company_contexts_updated_at before update on public.interview_company_contexts for each row execute function public.set_updated_at();

drop trigger if exists interview_sessions_updated_at on public.interview_sessions;
create trigger interview_sessions_updated_at before update on public.interview_sessions for each row execute function public.set_updated_at();

-- =========================================================
-- SECURITY HOOK: AUTOMATIC PROFILE SIGNUP PIPELINE
-- =========================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, full_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'username',
      split_part(new.email, '@', 1),
      'player'
    ),
    new.raw_user_meta_data ->> 'full_name'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- =========================================================
-- SECURITY SECTION: ROW LEVEL SECURITY (RLS) POLICIES
-- =========================================================
alter table public.profiles enable row level security;
alter table public.questions enable row level security;
alter table public.practice_sessions enable row level security;
alter table public.practice_session_questions enable row level security;
alter table public.practice_answers enable row level security;
alter table public.match_results enable row level security;
alter table public.match_question_pool enable row level security;
alter table public.match_logs enable row level security;
alter table public.interview_company_profiles enable row level security;
alter table public.interview_company_contexts enable row level security;
alter table public.interview_sessions enable row level security;
alter table public.interview_turns enable row level security;

-- Profiles Policies
drop policy if exists "Profiles are readable by authenticated users" on public.profiles;
create policy "Profiles are readable by authenticated users" on public.profiles for select to authenticated using (true);

drop policy if exists "Leaderboard profiles are readable by anon users" on public.profiles;
create policy "Leaderboard profiles are readable by anon users" on public.profiles for select to anon using (true);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Practice Loop Policies
drop policy if exists "Users can read their own practice sessions" on public.practice_sessions;
create policy "Users can read their own practice sessions" on public.practice_sessions for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can manage their own practice sessions" on public.practice_sessions;
create policy "Users can manage their own practice sessions" on public.practice_sessions for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can read their own practice session questions" on public.practice_session_questions;
create policy "Users can read their own practice session questions" on public.practice_session_questions for select to authenticated using (exists (select 1 from public.practice_sessions ps where ps.id = practice_session_questions.session_id and ps.user_id = auth.uid()));

drop policy if exists "Users can read their own practice answers" on public.practice_answers;
create policy "Users can read their own practice answers" on public.practice_answers for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can manage their own practice answers" on public.practice_answers;
create policy "Users can manage their own practice answers" on public.practice_answers for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- PvP Match Logging History Policies
drop policy if exists "Users can read their own match results" on public.match_results;
create policy "Users can read their own match results" on public.match_results for select to authenticated using (auth.uid() = player_a_id or auth.uid() = player_b_id);

drop policy if exists "Users can read own match question pool" on public.match_question_pool;
create policy "Users can read own match question pool" on public.match_question_pool for select to authenticated using (exists (select 1 from public.match_results mr where mr.id = match_question_pool.match_result_id and (mr.player_a_id = auth.uid() or mr.player_b_id = auth.uid())));

drop policy if exists "Users can read own match logs" on public.match_logs;
create policy "Users can read own match logs" on public.match_logs for select to authenticated using (exists (select 1 from public.match_results mr where mr.id = match_logs.match_result_id and (mr.player_a_id = auth.uid() or mr.player_b_id = auth.uid())));

-- Static Corporate Knowledge Base Access (Open Read-only to Authenticated Users)
drop policy if exists "Company profiles are readable by authenticated users" on public.interview_company_profiles;
create policy "Company profiles are readable by authenticated users" on public.interview_company_profiles for select to authenticated using (true);

drop policy if exists "Company contexts are readable by authenticated users" on public.interview_company_contexts;
create policy "Company contexts are readable by authenticated users" on public.interview_company_contexts for select to authenticated using (true);

-- User-Isolated AI Interview Policies (CRITICAL CORRECTION)
drop policy if exists "Users can access their own interview sessions" on public.interview_sessions;
create policy "Users can access their own interview sessions" on public.interview_sessions for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can access turns belonging to their active sessions" on public.interview_turns;
create policy "Users can access turns belonging to their active sessions" on public.interview_turns for all to authenticated using (exists (select 1 from public.interview_sessions s where s.id = interview_turns.session_id and s.user_id = auth.uid()));
