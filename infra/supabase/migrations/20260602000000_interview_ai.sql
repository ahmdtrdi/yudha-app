create extension if not exists pgcrypto;

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

create index if not exists interview_company_contexts_company_priority_idx
  on public.interview_company_contexts (company_id, priority);

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

create index if not exists interview_sessions_user_created_idx
  on public.interview_sessions (user_id, created_at desc);

create table if not exists public.interview_turns (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.interview_sessions(id) on delete cascade,
  role text not null check (role in ('question', 'answer')),
  content text not null,
  idempotency_key text,
  parent_turn_id uuid references public.interview_turns(id) on delete set null,
  processing_status text
    check (processing_status in ('pending', 'completed', 'failed')),
  evaluation jsonb,
  created_at timestamptz not null default now()
);

create index if not exists interview_turns_session_created_idx
  on public.interview_turns (session_id, created_at);

create unique index if not exists interview_turns_session_idempotency_idx
  on public.interview_turns (session_id, idempotency_key)
  where idempotency_key is not null;

create unique index if not exists interview_turns_session_pending_answer_idx
  on public.interview_turns (session_id)
  where role = 'answer' and processing_status = 'pending';

create unique index if not exists interview_turns_parent_question_idx
  on public.interview_turns (parent_turn_id)
  where role = 'question' and parent_turn_id is not null;

create or replace function public.set_interview_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists interview_company_profiles_updated_at
  on public.interview_company_profiles;
create trigger interview_company_profiles_updated_at
  before update on public.interview_company_profiles
  for each row execute function public.set_interview_updated_at();

drop trigger if exists interview_company_contexts_updated_at
  on public.interview_company_contexts;
create trigger interview_company_contexts_updated_at
  before update on public.interview_company_contexts
  for each row execute function public.set_interview_updated_at();

drop trigger if exists interview_sessions_updated_at
  on public.interview_sessions;
create trigger interview_sessions_updated_at
  before update on public.interview_sessions
  for each row execute function public.set_interview_updated_at();

alter table public.interview_company_profiles enable row level security;
alter table public.interview_company_contexts enable row level security;
alter table public.interview_sessions enable row level security;
alter table public.interview_turns enable row level security;
