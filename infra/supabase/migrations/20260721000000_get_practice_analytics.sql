-- =========================================================
-- Migration: get_practice_analytics RPC
-- Purpose: Efficiently aggregate practice stats per user on PostgreSQL
-- =========================================================

create or replace function public.get_practice_analytics(p_user_id uuid)
returns table (
  category text,
  subcategory text,
  total_answered bigint,
  total_correct bigint,
  avg_response_time_ms numeric
)
language sql stable
security definer
set search_path = public
as $$
  select
    q.category,
    q.subcategory,
    count(*)::bigint as total_answered,
    count(*) filter (where pa.is_correct)::bigint as total_correct,
    round(avg(pa.response_time_ms)::numeric, 2) as avg_response_time_ms
  from public.practice_answers pa
  join public.questions q on q.id = pa.question_id
  where pa.user_id = p_user_id
  group by q.category, q.subcategory;
$$;
