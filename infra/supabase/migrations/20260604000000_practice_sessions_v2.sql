alter table public.profiles
add column if not exists target text not null default 'cpns';

alter table public.profiles
drop constraint if exists profiles_target_check;

alter table public.profiles
add constraint profiles_target_check
check (target in ('cpns', 'bumn', 'kedinasan'));

alter table public.questions
add column if not exists target text not null default 'cpns';

alter table public.questions
drop constraint if exists questions_target_check;

alter table public.questions
add constraint questions_target_check
check (target in ('cpns', 'bumn', 'kedinasan'));

alter table public.practice_sessions
add column if not exists target text not null default 'cpns';

alter table public.practice_sessions
add column if not exists subcategory text;

alter table public.practice_sessions
drop constraint if exists practice_sessions_target_check;

alter table public.practice_sessions
add constraint practice_sessions_target_check
check (target in ('cpns', 'bumn', 'kedinasan'));

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

alter table public.practice_answers
add column if not exists session_question_id uuid
references public.practice_session_questions(id) on delete cascade;

create index if not exists questions_active_target_category_subcategory_idx
on public.questions (is_active, target, category, subcategory);

create index if not exists practice_sessions_user_target_category_started_idx
on public.practice_sessions (user_id, target, category, subcategory, started_at desc);

create index if not exists practice_session_questions_session_order_idx
on public.practice_session_questions (session_id, question_order);

create unique index if not exists practice_answers_session_question_unique_idx
on public.practice_answers (session_question_id)
where session_question_id is not null;

create or replace view public.public_questions
with (security_invoker = true)
as
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

grant select on public.public_questions to authenticated;

alter table public.practice_session_questions enable row level security;

drop policy if exists "Users can read their own practice session questions"
on public.practice_session_questions;

create policy "Users can read their own practice session questions"
on public.practice_session_questions
for select
to authenticated
using (
  exists (
    select 1
    from public.practice_sessions ps
    where ps.id = practice_session_questions.session_id
      and ps.user_id = auth.uid()
  )
);
