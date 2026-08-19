alter table public.match_results
  drop constraint if exists match_results_mode_check;

alter table public.match_results
  add constraint match_results_mode_check
  check (mode in ('ranked', 'casual', 'bot', 'private'));

alter function public.finalize_match_result(
  text, text, text, uuid, uuid, uuid, uuid, text, text,
  integer, integer, integer, integer, integer, timestamptz
) rename to finalize_public_match_result;

create function public.finalize_match_result(
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
  v_completed_at timestamptz := clock_timestamp();
begin
  if p_mode is distinct from 'private' then
    return public.finalize_public_match_result(
      p_room_id,
      p_mode,
      p_target,
      p_player_a_id,
      p_player_b_id,
      p_winner_user_id,
      p_loser_user_id,
      p_outcome,
      p_reason,
      p_player_a_hp,
      p_player_b_hp,
      p_player_a_points,
      p_player_b_points,
      p_duration_seconds,
      p_started_at
    );
  end if;

  if p_target not in ('cpns', 'bumn') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported battle target';
  end if;
  if p_outcome not in ('player_a_win', 'player_b_win', 'draw') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported match outcome';
  end if;
  if p_player_a_id is null or p_player_b_id is null or p_player_a_id = p_player_b_id then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: private matches require two distinct players';
  end if;

  insert into public.match_results(
    room_id,
    mode,
    target,
    player_a_id,
    player_b_id,
    winner_user_id,
    loser_user_id,
    outcome,
    reason,
    player_a_hp,
    player_b_hp,
    player_a_points,
    player_b_points,
    rating_delta_a,
    rating_delta_b,
    coins_delta_a,
    coins_delta_b,
    duration_seconds,
    started_at,
    ended_at
  ) values (
    p_room_id,
    'private',
    p_target,
    p_player_a_id,
    p_player_b_id,
    p_winner_user_id,
    p_loser_user_id,
    p_outcome,
    p_reason,
    p_player_a_hp,
    p_player_b_hp,
    p_player_a_points,
    p_player_b_points,
    0,
    0,
    0,
    0,
    p_duration_seconds,
    p_started_at,
    v_completed_at
  )
  on conflict (room_id) do nothing
  returning * into v_result;

  if v_result.id is null then
    select * into v_result
    from public.match_results
    where room_id = p_room_id;

    return jsonb_build_object(
      'persisted', false,
      'reason', 'duplicate',
      'matchResultId', v_result.id,
      'ratingDeltaA', v_result.rating_delta_a,
      'ratingDeltaB', v_result.rating_delta_b,
      'coinsDeltaA', v_result.coins_delta_a,
      'coinsDeltaB', v_result.coins_delta_b,
      'progressionApplied', false
    );
  end if;

  return jsonb_build_object(
    'persisted', true,
    'matchResultId', v_result.id,
    'ratingDeltaA', 0,
    'ratingDeltaB', 0,
    'coinsDeltaA', 0,
    'coinsDeltaB', 0,
    'progressionApplied', false,
    'dailyMissionA', null,
    'dailyMissionB', null,
    'streakA', null,
    'streakB', null
  );
end;
$$;

revoke all on function public.finalize_public_match_result(
  text, text, text, uuid, uuid, uuid, uuid, text, text,
  integer, integer, integer, integer, integer, timestamptz
) from public, anon, authenticated;

revoke all on function public.finalize_match_result(
  text, text, text, uuid, uuid, uuid, uuid, text, text,
  integer, integer, integer, integer, integer, timestamptz
) from public, anon, authenticated;

grant execute on function public.finalize_match_result(
  text, text, text, uuid, uuid, uuid, uuid, text, text,
  integer, integer, integer, integer, integer, timestamptz
) to service_role;

revoke all on function public.finalize_match_result(
  uuid, uuid, uuid, text, integer, integer, integer, integer, text, boolean
) from public, anon, authenticated;

grant execute on function public.finalize_match_result(
  uuid, uuid, uuid, text, integer, integer, integer, integer, text, boolean
) to service_role;
