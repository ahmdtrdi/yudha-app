-- =========================================================
-- YUDHA Supabase Bootstrap Schema
-- Run this in the Supabase SQL editor for a fresh project.
-- Supabase Auth (`auth.users`) is the source user table.
-- =========================================================

create extension if not exists "pgcrypto";

-- Optional later if vector search is added:
-- create extension if not exists "vector";

-- =========================================================
-- 1. PROFILES
-- =========================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  full_name text,
  rank_points integer not null default 1000,
  total_matches integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  winrate numeric(5, 2) not null default 0,
  coins integer not null default 0,
  equipped_avatar_id text,
  equipped_arena_id text,
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
  )
);

-- =========================================================
-- 2. QUESTIONS
-- Internal authoritative question table.
-- Frontend should not directly receive correct_option_index.
-- =========================================================

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
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
-- Hides correct_option_index and explanation.
-- =========================================================

create or replace view public.public_questions as
select
  id,
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
  category text,
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
  )
);

-- =========================================================
-- 5. PRACTICE ANSWERS
-- =========================================================

create table if not exists public.practice_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.practice_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
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
-- 6. MATCH RESULTS
-- Final match summary. Detailed actions go to match_logs.
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
-- Shared queue snapshot for fairness, replay, and analytics.
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
-- Individual player actions for analytics and review.
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
-- 9. AI INTERVIEW
-- =========================================================

create table if not exists public.interview_mockups (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  overall_score numeric(5, 2),
  ai_feedback text,
  created_at timestamptz not null default now(),
  constraint interview_mockups_score_check check (
    overall_score is null
    or (overall_score >= 0 and overall_score <= 100)
  )
);

create table if not exists public.interview_messages (
  id uuid primary key default gen_random_uuid(),
  mockup_session_id uuid not null references public.interview_mockups(id) on delete cascade,
  sender text not null,
  message text not null,
  created_at timestamptz not null default now(),
  constraint interview_messages_sender_check check (sender in ('user', 'ai', 'system'))
);

-- =========================================================
-- 10. CONTENT AND DOCUMENTS
-- =========================================================

create table if not exists public.institutions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references public.institutions(id) on delete set null,
  title text not null,
  source text,
  uploaded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.document_chunks (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  institution_id uuid references public.institutions(id) on delete set null,
  text text not null,
  -- Later if pgvector is enabled:
  -- embedding vector(1536),
  created_at timestamptz not null default now()
);

-- =========================================================
-- INDEXES
-- =========================================================

create index if not exists profiles_rank_points_idx on public.profiles (rank_points desc);
create index if not exists questions_active_category_idx on public.questions (is_active, category);
create index if not exists practice_sessions_user_started_idx on public.practice_sessions (user_id, started_at desc);
create index if not exists practice_answers_user_created_idx on public.practice_answers (user_id, created_at desc);
create index if not exists practice_answers_session_order_idx on public.practice_answers (session_id, question_order);
create index if not exists match_results_player_a_idx on public.match_results (player_a_id, created_at desc);
create index if not exists match_results_player_b_idx on public.match_results (player_b_id, created_at desc);
create index if not exists match_results_winner_idx on public.match_results (winner_user_id, created_at desc);
create index if not exists match_question_pool_match_order_idx on public.match_question_pool (match_result_id, card_order);
create index if not exists match_logs_match_timestamp_idx on public.match_logs (match_result_id, action_timestamp);
create index if not exists match_logs_player_timestamp_idx on public.match_logs (player_id, action_timestamp desc);
create index if not exists interview_mockups_player_created_idx on public.interview_mockups (player_id, created_at desc);
create index if not exists interview_messages_session_created_idx on public.interview_messages (mockup_session_id, created_at);
create index if not exists institutions_type_idx on public.institutions (type);
create index if not exists documents_institution_idx on public.documents (institution_id);
create index if not exists document_chunks_document_idx on public.document_chunks (document_id);
create index if not exists document_chunks_institution_idx on public.document_chunks (institution_id);

-- =========================================================
-- UPDATED_AT TRIGGERS
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

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_questions_updated_at on public.questions;
create trigger set_questions_updated_at
before update on public.questions
for each row execute function public.set_updated_at();

drop trigger if exists set_institutions_updated_at on public.institutions;
create trigger set_institutions_updated_at
before update on public.institutions
for each row execute function public.set_updated_at();

drop trigger if exists set_documents_updated_at on public.documents;
create trigger set_documents_updated_at
before update on public.documents
for each row execute function public.set_updated_at();

-- =========================================================
-- AUTO-CREATE PROFILE AFTER SIGNUP
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
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.profiles enable row level security;
alter table public.questions enable row level security;
alter table public.practice_sessions enable row level security;
alter table public.practice_answers enable row level security;
alter table public.match_results enable row level security;
alter table public.match_question_pool enable row level security;
alter table public.match_logs enable row level security;
alter table public.interview_mockups enable row level security;
alter table public.interview_messages enable row level security;
alter table public.institutions enable row level security;
alter table public.documents enable row level security;
alter table public.document_chunks enable row level security;

-- Profiles

drop policy if exists "Profiles are readable by authenticated users" on public.profiles;
create policy "Profiles are readable by authenticated users"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "Leaderboard profiles are readable by anon users" on public.profiles;
create policy "Leaderboard profiles are readable by anon users"
on public.profiles for select
to anon
using (true);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- Questions
-- No direct authenticated select policy on full questions table.
-- Backend service-role code can read full questions.
-- Frontend should use public.public_questions or backend APIs.

drop policy if exists "Active questions are readable by authenticated users" on public.questions;

-- Practice

drop policy if exists "Users can read their own practice sessions" on public.practice_sessions;
create policy "Users can read their own practice sessions"
on public.practice_sessions for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can manage their own practice sessions" on public.practice_sessions;
create policy "Users can manage their own practice sessions"
on public.practice_sessions for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can read their own practice answers" on public.practice_answers;
create policy "Users can read their own practice answers"
on public.practice_answers for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can manage their own practice answers" on public.practice_answers;
create policy "Users can manage their own practice answers"
on public.practice_answers for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Match history

drop policy if exists "Users can read their own match results" on public.match_results;
create policy "Users can read their own match results"
on public.match_results for select
to authenticated
using (auth.uid() = player_a_id or auth.uid() = player_b_id);

drop policy if exists "Users can read own match question pool" on public.match_question_pool;
create policy "Users can read own match question pool"
on public.match_question_pool for select
to authenticated
using (
  exists (
    select 1
    from public.match_results mr
    where mr.id = match_question_pool.match_result_id
      and (mr.player_a_id = auth.uid() or mr.player_b_id = auth.uid())
  )
);

drop policy if exists "Users can read own match logs" on public.match_logs;
create policy "Users can read own match logs"
on public.match_logs for select
to authenticated
using (
  exists (
    select 1
    from public.match_results mr
    where mr.id = match_logs.match_result_id
      and (mr.player_a_id = auth.uid() or mr.player_b_id = auth.uid())
  )
);

-- AI interview

drop policy if exists "Users can read their own interview mockups" on public.interview_mockups;
create policy "Users can read their own interview mockups"
on public.interview_mockups for select
to authenticated
using (auth.uid() = player_id);

drop policy if exists "Users can manage their own interview mockups" on public.interview_mockups;
create policy "Users can manage their own interview mockups"
on public.interview_mockups for all
to authenticated
using (auth.uid() = player_id)
with check (auth.uid() = player_id);

drop policy if exists "Users can read their own interview messages" on public.interview_messages;
create policy "Users can read their own interview messages"
on public.interview_messages for select
to authenticated
using (
  exists (
    select 1
    from public.interview_mockups im
    where im.id = interview_messages.mockup_session_id
      and im.player_id = auth.uid()
  )
);

drop policy if exists "Users can manage their own interview messages" on public.interview_messages;
create policy "Users can manage their own interview messages"
on public.interview_messages for all
to authenticated
using (
  exists (
    select 1
    from public.interview_mockups im
    where im.id = interview_messages.mockup_session_id
      and im.player_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.interview_mockups im
    where im.id = interview_messages.mockup_session_id
      and im.player_id = auth.uid()
  )
);

-- Content/document tables
-- Reads are open to authenticated users for now.
-- Writes should happen through backend service-role/admin flows.

drop policy if exists "Institutions are readable by authenticated users" on public.institutions;
create policy "Institutions are readable by authenticated users"
on public.institutions for select
to authenticated
using (true);

drop policy if exists "Documents are readable by authenticated users" on public.documents;
create policy "Documents are readable by authenticated users"
on public.documents for select
to authenticated
using (true);

drop policy if exists "Document chunks are readable by authenticated users" on public.document_chunks;
create policy "Document chunks are readable by authenticated users"
on public.document_chunks for select
to authenticated
using (true);
