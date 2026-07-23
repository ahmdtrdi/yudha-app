-- =========================================================
-- Migration: finalize_match_result RPC
-- Purpose: Atomically persist match results + update profile stats
-- =========================================================

create or replace function public.finalize_match_result(
  p_room_id text,
  p_mode text,                -- 'player' | 'bot'
  p_player_a_id uuid,
  p_player_b_id uuid,         -- null for bot matches
  p_winner_user_id uuid,       -- null for draw
  p_loser_user_id uuid,        -- null for draw
  p_outcome text,              -- 'player_a_win' | 'player_b_win' | 'draw'
  p_reason text,               -- 'hp_zero' | 'round_timeout' | 'surrender' | 'question_exhaustion' | 'draw'
  p_player_a_hp int,
  p_player_b_hp int,
  p_player_a_points int,
  p_player_b_points int,
  p_duration_seconds int default null,
  p_started_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result_id uuid;
  v_is_bot boolean;
  v_rating_delta_a int := 0;
  v_rating_delta_b int := 0;
  v_coins_delta_a int := 0;
  v_coins_delta_b int := 0;
  v_rating_win constant int := 20;
  v_rating_lose constant int := -12;
  v_coins_win constant int := 10;
  v_coins_lose constant int := 3;
  v_coins_draw constant int := 5;
begin
  v_is_bot := (p_mode = 'bot');

  -- Compute rating deltas (only for player matches)
  if not v_is_bot then
    if p_outcome = 'player_a_win' then
      v_rating_delta_a := v_rating_win;
      v_rating_delta_b := v_rating_lose;
    elsif p_outcome = 'player_b_win' then
      v_rating_delta_a := v_rating_lose;
      v_rating_delta_b := v_rating_win;
    else -- draw
      v_rating_delta_a := 0;
      v_rating_delta_b := 0;
    end if;
  end if;

  -- Compute coin deltas (always, including bot matches)
  if p_outcome = 'player_a_win' then
    v_coins_delta_a := v_coins_win;
    v_coins_delta_b := v_coins_lose;
  elsif p_outcome = 'player_b_win' then
    v_coins_delta_a := v_coins_lose;
    v_coins_delta_b := v_coins_win;
  else -- draw
    v_coins_delta_a := v_coins_draw;
    v_coins_delta_b := v_coins_draw;
  end if;

  -- For bot matches, player_b deltas are irrelevant (no profile to update)
  if v_is_bot then
    v_coins_delta_b := 0;
    v_rating_delta_b := 0;
  end if;

  -- Insert match result (idempotent via unique room_id constraint)
  insert into public.match_results (
    room_id, mode,
    player_a_id, player_b_id,
    winner_user_id, loser_user_id,
    outcome, reason,
    player_a_hp, player_b_hp,
    player_a_points, player_b_points,
    rating_delta_a, rating_delta_b,
    coins_delta_a, coins_delta_b,
    duration_seconds, started_at,
    ended_at
  ) values (
    p_room_id, p_mode,
    p_player_a_id, p_player_b_id,
    p_winner_user_id, p_loser_user_id,
    p_outcome, p_reason,
    p_player_a_hp, p_player_b_hp,
    p_player_a_points, p_player_b_points,
    v_rating_delta_a, v_rating_delta_b,
    v_coins_delta_a, v_coins_delta_b,
    p_duration_seconds, p_started_at,
    now()
  )
  on conflict (room_id) do nothing
  returning id into v_result_id;

  -- If already recorded (duplicate), return early with a flag
  if v_result_id is null then
    return jsonb_build_object('persisted', false, 'reason', 'duplicate');
  end if;

  -- Update player A profile
  update public.profiles set
    rank_points = greatest(0, rank_points + v_rating_delta_a),
    total_matches = total_matches + 1,
    wins = wins + (case when p_winner_user_id = p_player_a_id then 1 else 0 end),
    losses = losses + (case when p_loser_user_id = p_player_a_id then 1 else 0 end),
    winrate = case
      when (total_matches + 1) = 0 then 0
      else round(
        (wins + (case when p_winner_user_id = p_player_a_id then 1 else 0 end))::numeric
        / (total_matches + 1) * 100, 2
      )
    end,
    coins = coins + v_coins_delta_a
  where id = p_player_a_id;

  -- Update player B profile (skip for bot matches)
  if not v_is_bot and p_player_b_id is not null then
    update public.profiles set
      rank_points = greatest(0, rank_points + v_rating_delta_b),
      total_matches = total_matches + 1,
      wins = wins + (case when p_winner_user_id = p_player_b_id then 1 else 0 end),
      losses = losses + (case when p_loser_user_id = p_player_b_id then 1 else 0 end),
      winrate = case
        when (total_matches + 1) = 0 then 0
        else round(
          (wins + (case when p_winner_user_id = p_player_b_id then 1 else 0 end))::numeric
          / (total_matches + 1) * 100, 2
        )
      end,
      coins = coins + v_coins_delta_b
    where id = p_player_b_id;
  end if;

  return jsonb_build_object(
    'persisted', true,
    'matchResultId', v_result_id,
    'ratingDeltaA', v_rating_delta_a,
    'ratingDeltaB', v_rating_delta_b,
    'coinsDeltaA', v_coins_delta_a,
    'coinsDeltaB', v_coins_delta_b
  );
end;
$$;
