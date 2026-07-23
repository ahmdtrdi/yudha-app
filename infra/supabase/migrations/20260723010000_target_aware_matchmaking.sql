begin;

alter table public.match_results
  add column if not exists target text not null default 'cpns';

alter table public.match_results
  drop constraint if exists match_results_target_check;
alter table public.match_results
  add constraint match_results_target_check
    check (target in ('cpns', 'bumn'));

alter table public.match_results
  drop constraint if exists match_results_mode_check;
update public.match_results
set mode = 'ranked'
where mode = 'player';
alter table public.match_results
  add constraint match_results_mode_check
    check (mode in ('ranked', 'casual', 'bot'));

drop function if exists public.finalize_match_result(
  text,
  text,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  text,
  integer,
  integer,
  integer,
  integer,
  integer,
  timestamptz
);

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
  v_result public.match_results%rowtype;
  v_is_bot boolean;
  v_progression_enabled boolean;
  v_rating_delta_a int := 0;
  v_rating_delta_b int := 0;
  v_coins_delta_a int := 0;
  v_coins_delta_b int := 0;
  v_balance_a int;
  v_balance_b int;
  v_rating_win constant int := 20;
  v_rating_lose constant int := -12;
  v_coins_win constant int := 10;
  v_coins_lose constant int := 3;
  v_coins_draw constant int := 5;
begin
  if p_mode not in ('ranked', 'casual', 'bot') then
    raise exception 'Unsupported match mode.';
  end if;
  if p_target not in ('cpns', 'bumn') then
    raise exception 'Unsupported battle target.';
  end if;
  if p_outcome not in ('player_a_win', 'player_b_win', 'draw') then
    raise exception 'Unsupported match outcome.';
  end if;

  v_is_bot := (p_mode = 'bot');
  v_progression_enabled :=
    p_mode = 'ranked'
    and not (
      p_reason = 'disconnect'
      and p_winner_user_id is null
      and p_loser_user_id is null
    );

  if v_progression_enabled then
    if p_outcome = 'player_a_win' then
      v_rating_delta_a := v_rating_win;
      v_rating_delta_b := v_rating_lose;
      v_coins_delta_a := v_coins_win;
      v_coins_delta_b := v_coins_lose;
    elsif p_outcome = 'player_b_win' then
      v_rating_delta_a := v_rating_lose;
      v_rating_delta_b := v_rating_win;
      v_coins_delta_a := v_coins_lose;
      v_coins_delta_b := v_coins_win;
    else
      v_coins_delta_a := v_coins_draw;
      v_coins_delta_b := v_coins_draw;
    end if;
  end if;

  if v_is_bot then
    v_rating_delta_b := 0;
    v_coins_delta_b := 0;
  end if;

  insert into public.match_results (
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
  )
  values (
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
    v_rating_delta_a,
    v_rating_delta_b,
    v_coins_delta_a,
    v_coins_delta_b,
    p_duration_seconds,
    p_started_at,
    now()
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
      'progressionApplied',
        v_result.mode = 'ranked'
        and not (
          v_result.reason = 'disconnect'
          and v_result.winner_user_id is null
          and v_result.loser_user_id is null
        )
    );
  end if;

  if v_progression_enabled then
    update public.profiles set
      rank_points = greatest(0, rank_points + v_rating_delta_a),
      total_matches = total_matches + 1,
      wins = wins + (case when p_winner_user_id = p_player_a_id then 1 else 0 end),
      losses = losses + (case when p_loser_user_id = p_player_a_id then 1 else 0 end),
      winrate = round(
        (
          wins + (case when p_winner_user_id = p_player_a_id then 1 else 0 end)
        )::numeric / (total_matches + 1) * 100,
        2
      ),
      coins = coins + v_coins_delta_a
    where id = p_player_a_id
    returning coins into v_balance_a;

    if not found then
      raise exception 'Player A profile not found.';
    end if;

    insert into public.coin_transactions
      (user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values
      (
        p_player_a_id,
        v_coins_delta_a,
        'match_reward',
        p_room_id,
        'match:' || p_room_id || ':player-a',
        v_balance_a
      );

    perform public.record_hired_pass_activity(
      p_player_a_id,
      'battle_completed',
      p_room_id,
      now()
    );

    if not v_is_bot and p_player_b_id is not null then
      update public.profiles set
        rank_points = greatest(0, rank_points + v_rating_delta_b),
        total_matches = total_matches + 1,
        wins = wins + (case when p_winner_user_id = p_player_b_id then 1 else 0 end),
        losses = losses + (case when p_loser_user_id = p_player_b_id then 1 else 0 end),
        winrate = round(
          (
            wins + (case when p_winner_user_id = p_player_b_id then 1 else 0 end)
          )::numeric / (total_matches + 1) * 100,
          2
        ),
        coins = coins + v_coins_delta_b
      where id = p_player_b_id
      returning coins into v_balance_b;

      if not found then
        raise exception 'Player B profile not found.';
      end if;

      insert into public.coin_transactions
        (user_id, delta, reason, reference_id, idempotency_key, balance_after)
      values
        (
          p_player_b_id,
          v_coins_delta_b,
          'match_reward',
          p_room_id,
          'match:' || p_room_id || ':player-b',
          v_balance_b
        );

      perform public.record_hired_pass_activity(
        p_player_b_id,
        'battle_completed',
        p_room_id,
        now()
      );
    end if;
  end if;

  return jsonb_build_object(
    'persisted', true,
    'matchResultId', v_result.id,
    'ratingDeltaA', v_rating_delta_a,
    'ratingDeltaB', v_rating_delta_b,
    'coinsDeltaA', v_coins_delta_a,
    'coinsDeltaB', v_coins_delta_b,
    'progressionApplied', v_progression_enabled
  );
end;
$$;

revoke all on function public.finalize_match_result(
  text,
  text,
  text,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  text,
  integer,
  integer,
  integer,
  integer,
  integer,
  timestamptz
) from public;

grant execute on function public.finalize_match_result(
  text,
  text,
  text,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  text,
  integer,
  integer,
  integer,
  integer,
  integer,
  timestamptz
) to service_role;

commit;
