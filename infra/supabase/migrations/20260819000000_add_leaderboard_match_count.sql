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