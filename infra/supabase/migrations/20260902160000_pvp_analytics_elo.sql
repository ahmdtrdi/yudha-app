begin;

-- PvP rating is deliberately scoped by target. A user can be rated in both
-- CPNS and BUMN without either history leaking into the other leaderboard.
create table if not exists public.pvp_ratings (
  user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  rating integer not null default 1000,
  rated_matches integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  draws integer not null default 0,
  algorithm_version text not null default 'elo-v1',
  last_match_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, target),
  constraint pvp_ratings_target_check check (target in ('cpns', 'bumn')),
  constraint pvp_ratings_non_negative_check check (
    rating >= 0 and rated_matches >= 0 and wins >= 0 and losses >= 0 and draws >= 0
  ),
  constraint pvp_ratings_record_check check (rated_matches = wins + losses + draws),
  constraint pvp_ratings_algorithm_check check (algorithm_version = 'elo-v1')
);

create table if not exists public.pvp_rating_events (
  id uuid primary key default gen_random_uuid(),
  match_result_id uuid not null references public.match_results(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  opponent_user_id uuid not null references public.profiles(id) on delete cascade,
  target text not null,
  rating_before integer not null,
  expected_score numeric(9,8) not null,
  actual_score numeric(2,1) not null,
  rating_delta integer not null,
  rating_after integer not null,
  algorithm_version text not null default 'elo-v1',
  created_at timestamptz not null,
  constraint pvp_rating_events_unique unique (match_result_id, user_id),
  constraint pvp_rating_events_target_check check (target in ('cpns', 'bumn')),
  constraint pvp_rating_events_rating_check check (rating_before >= 0 and rating_after >= 0),
  constraint pvp_rating_events_expected_check check (expected_score between 0 and 1),
  constraint pvp_rating_events_actual_check check (actual_score in (0, 0.5, 1)),
  constraint pvp_rating_events_algorithm_check check (algorithm_version = 'elo-v1')
);

create index if not exists pvp_ratings_target_order_idx
  on public.pvp_ratings(target, rating desc, wins desc, user_id asc)
  where rated_matches > 0;
create index if not exists pvp_rating_events_user_target_created_idx
  on public.pvp_rating_events(user_id, target, created_at desc);

alter table public.pvp_ratings enable row level security;
alter table public.pvp_rating_events enable row level security;
revoke all on public.pvp_ratings, public.pvp_rating_events from public, anon, authenticated;
grant all on public.pvp_ratings, public.pvp_rating_events to service_role;

-- Immutable metadata captured when the battle question is dealt. Old rows stay
-- null and therefore remain broad, explicitly labelled legacy evidence.
alter table public.match_logs
  add column if not exists question_revision_id uuid references public.question_revisions(id) on delete restrict,
  add column if not exists taxonomy_version_id uuid,
  add column if not exists skill_id text,
  add column if not exists category_snapshot text,
  add column if not exists subcategory_snapshot text,
  add column if not exists difficulty_snapshot text,
  add column if not exists expected_time_ms integer,
  add column if not exists time_limit_ms integer,
  add column if not exists opened_at timestamptz,
  add column if not exists answered_at timestamptz;

alter table public.match_logs drop constraint if exists match_logs_skill_fkey;
alter table public.match_logs add constraint match_logs_skill_fkey
  foreign key (taxonomy_version_id, skill_id)
  references public.learning_skills(taxonomy_version_id, skill_id)
  on delete restrict;
alter table public.match_logs drop constraint if exists match_logs_skill_pair_check;
alter table public.match_logs add constraint match_logs_skill_pair_check check (
  (taxonomy_version_id is null and skill_id is null)
  or (taxonomy_version_id is not null and nullif(btrim(skill_id), '') is not null)
);
alter table public.match_logs drop constraint if exists match_logs_difficulty_snapshot_check;
alter table public.match_logs add constraint match_logs_difficulty_snapshot_check check (
  difficulty_snapshot is null or difficulty_snapshot in ('easy', 'medium', 'hard')
);
alter table public.match_logs drop constraint if exists match_logs_time_limit_check;
alter table public.match_logs add constraint match_logs_time_limit_check check (
  (time_limit_ms is null or time_limit_ms > 0)
  and (expected_time_ms is null or expected_time_ms > 0)
);

-- Rank Points are retired. Historical columns remain readable for rollback and
-- audit, while new daily mission rewards are recorded as YCoin.
alter table public.coin_transactions drop constraint if exists coin_transactions_reason_check;
alter table public.coin_transactions add constraint coin_transactions_reason_check check (
  reason in ('match_reward', 'solo_reward', 'store_purchase', 'hired_pass_reward', 'beta_credit', 'daily_mission', 'admin')
);
alter table public.daily_mission_progress
  alter column reward_rank_points set default 0,
  alter column rank_transaction_id drop not null,
  add column if not exists reward_ycoins integer not null default 0,
  add column if not exists coin_transaction_id uuid references public.coin_transactions(id) on delete set null;
alter table public.daily_mission_progress drop constraint if exists daily_mission_reward_check;
alter table public.daily_mission_progress add constraint daily_mission_reward_check check (
  reward_rank_points in (0, 50, 80) and reward_ycoins in (0, 1, 2)
);

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
  v_reward := case p_mission_key when 'daily_practice' then 2 when 'daily_pvp' then 1 else null end;
  if v_reward is null then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported daily mission';
  end if;

  select coins into v_balance from public.profiles where id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;

  if exists (
    select 1 from public.daily_mission_progress
    where user_id = p_user_id and mission_key = p_mission_key and business_date = v_date
  ) then
    return jsonb_build_object(
      'key', p_mission_key, 'businessDate', v_date, 'awarded', false,
      'rewardYCoins', 0, 'yCoins', v_balance
    );
  end if;

  update public.profiles
  set coins = coins + v_reward, updated_at = p_completed_at
  where id = p_user_id
  returning coins into v_balance;

  insert into public.coin_transactions
    (user_id, delta, reason, reference_id, idempotency_key, balance_after, created_at)
  values
    (p_user_id, v_reward, 'daily_mission', p_source_id,
     'daily:' || p_mission_key || ':' || v_date::text, v_balance, p_completed_at)
  returning id into v_transaction_id;

  insert into public.daily_mission_progress(
    user_id, mission_key, business_date, source_type, source_id, completed_at,
    reward_rank_points, rank_transaction_id, reward_ycoins, coin_transaction_id
  ) values (
    p_user_id, p_mission_key, v_date, p_source_type, p_source_id, p_completed_at,
    0, null, v_reward, v_transaction_id
  );

  return jsonb_build_object(
    'key', p_mission_key, 'businessDate', v_date, 'awarded', true,
    'rewardYCoins', v_reward, 'yCoins', v_balance
  );
end;
$$;

create or replace function public.get_target_leaderboard_page(
  p_user_id uuid,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_target text;
  v_items jsonb;
  v_total integer;
begin
  select target into v_target from public.profiles where id = p_user_id;
  if v_target not in ('cpns', 'bumn') then
    raise exception using errcode = 'P0001', message = 'TARGET_REQUIRED';
  end if;
  if p_limit not between 1 and 100 or p_offset < 0 then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: invalid pagination';
  end if;

  with ordered as (
    select row_number() over (order by rating.rating desc, rating.wins desc, rating.user_id asc) as rank,
      rating.*, profile.username
    from public.pvp_ratings rating
    join public.profiles profile on profile.id = rating.user_id
    where rating.target = v_target and rating.rated_matches > 0
  ), page as (
    select * from ordered order by rank limit p_limit offset p_offset
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'rank', rank, 'userId', user_id, 'username', username,
    'pvpRating', rating, 'ratedMatches', rated_matches,
    'rankedWins', wins, 'rankedLosses', losses, 'rankedDraws', draws,
    'rankedWinRate', case when rated_matches = 0 then null else round(wins::numeric / rated_matches, 4) end,
    'status', 'rated'
  ) order by rank), '[]'::jsonb) into v_items from page;

  select count(*) into v_total from public.pvp_ratings
  where target = v_target and rated_matches > 0;
  return jsonb_build_object('target', v_target, 'items', v_items, 'total', v_total);
end;
$$;

create or replace function public.get_target_leaderboard_rank(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_target text;
  v_row record;
  v_username text;
begin
  select target, username into v_target, v_username from public.profiles where id = p_user_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: profile';
  end if;
  if v_target not in ('cpns', 'bumn') then
    raise exception using errcode = 'P0001', message = 'TARGET_REQUIRED';
  end if;

  with ordered as (
    select row_number() over (order by rating desc, wins desc, user_id asc) as rank, *
    from public.pvp_ratings
    where target = v_target and rated_matches > 0
  ) select * into v_row from ordered where user_id = p_user_id;

  if v_row.user_id is null then
    return jsonb_build_object(
      'rank', null, 'userId', p_user_id, 'username', v_username,
      'pvpRating', 1000, 'ratedMatches', 0, 'rankedWins', 0,
      'rankedLosses', 0, 'rankedDraws', 0, 'rankedWinRate', null,
      'status', 'unrated', 'target', v_target
    );
  end if;

  return jsonb_build_object(
    'rank', v_row.rank, 'userId', v_row.user_id, 'username', v_username,
    'pvpRating', v_row.rating, 'ratedMatches', v_row.rated_matches,
    'rankedWins', v_row.wins, 'rankedLosses', v_row.losses,
    'rankedDraws', v_row.draws,
    'rankedWinRate', round(v_row.wins::numeric / v_row.rated_matches, 4),
    'status', 'rated', 'target', v_target
  );
end;
$$;

-- The active finalizer owns match persistence, Elo, match rewards, missions,
-- streaks and Hired Pass events in a single transaction.
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
  v_is_rated boolean;
  v_normal_public boolean;
  v_coins_delta_a integer := 0;
  v_coins_delta_b integer := 0;
  v_rating_a integer;
  v_rating_b integer;
  v_after_a integer;
  v_after_b integer;
  v_delta_a integer;
  v_delta_b integer;
  v_expected_a numeric;
  v_expected_b numeric;
  v_score_a numeric;
  v_score_b numeric;
  v_coin_balance integer;
  v_daily_a jsonb;
  v_daily_b jsonb;
  v_streak_a jsonb;
  v_streak_b jsonb;
  v_completed_at timestamptz := clock_timestamp();
begin
  if p_mode not in ('ranked', 'casual', 'bot', 'private') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported match mode';
  end if;
  if p_target not in ('cpns', 'bumn') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported battle target';
  end if;
  if p_outcome not in ('player_a_win', 'player_b_win', 'draw') then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: unsupported match outcome';
  end if;
  if p_player_a_id is null or (not v_is_bot and p_player_b_id is null) then
    raise exception using errcode = 'P0001', message = 'VALIDATION_FAILED: missing player';
  end if;

  v_is_rated := p_mode = 'ranked' and not v_is_bot and p_player_b_id is not null
    and not (p_reason = 'disconnect' and p_winner_user_id is null and p_loser_user_id is null);
  v_normal_public := p_mode in ('ranked', 'casual')
    and p_reason in ('hp_zero', 'round_timeout', 'question_exhaustion', 'draw');

  if v_is_rated then
    if p_outcome = 'player_a_win' then
      v_coins_delta_a := 10; v_coins_delta_b := 3;
    elsif p_outcome = 'player_b_win' then
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
    0, 0, v_coins_delta_a, case when v_is_bot then 0 else v_coins_delta_b end,
    p_duration_seconds, p_started_at, v_completed_at
  ) on conflict (room_id) do nothing returning * into v_result;

  if v_result.id is null then
    select * into v_result from public.match_results where room_id = p_room_id;
    return jsonb_build_object(
      'persisted', false, 'reason', 'duplicate', 'matchResultId', v_result.id,
      'pvpRatingDeltaA', (select rating_delta from public.pvp_rating_events where match_result_id = v_result.id and user_id = v_result.player_a_id),
      'pvpRatingDeltaB', (select rating_delta from public.pvp_rating_events where match_result_id = v_result.id and user_id = v_result.player_b_id),
      'pvpRatingAfterA', (select rating_after from public.pvp_rating_events where match_result_id = v_result.id and user_id = v_result.player_a_id),
      'pvpRatingAfterB', (select rating_after from public.pvp_rating_events where match_result_id = v_result.id and user_id = v_result.player_b_id),
      'coinsDeltaA', v_result.coins_delta_a, 'coinsDeltaB', v_result.coins_delta_b,
      'progressionApplied', exists(select 1 from public.pvp_rating_events where match_result_id = v_result.id)
    );
  end if;

  if v_is_rated then
    insert into public.pvp_ratings(user_id, target) values
      (p_player_a_id, p_target), (p_player_b_id, p_target)
    on conflict (user_id, target) do nothing;

    perform 1 from public.pvp_ratings
    where target = p_target and user_id in (p_player_a_id, p_player_b_id)
    order by user_id for update;
    perform 1 from public.profiles
    where id in (p_player_a_id, p_player_b_id)
    order by id for update;

    select rating into v_rating_a from public.pvp_ratings where user_id = p_player_a_id and target = p_target;
    select rating into v_rating_b from public.pvp_ratings where user_id = p_player_b_id and target = p_target;
    v_expected_a := 1 / (1 + power(10::numeric, (v_rating_b - v_rating_a)::numeric / 400));
    v_expected_b := 1 - v_expected_a;
    v_score_a := case p_outcome when 'player_a_win' then 1 when 'draw' then 0.5 else 0 end;
    v_score_b := 1 - v_score_a;
    v_delta_a := round(32 * (v_score_a - v_expected_a));
    v_delta_b := -v_delta_a;
    v_after_a := greatest(0, v_rating_a + v_delta_a);
    v_after_b := greatest(0, v_rating_b + v_delta_b);
    v_delta_a := v_after_a - v_rating_a;
    v_delta_b := v_after_b - v_rating_b;

    update public.pvp_ratings set
      rating = v_after_a, rated_matches = rated_matches + 1,
      wins = wins + case when p_outcome = 'player_a_win' then 1 else 0 end,
      losses = losses + case when p_outcome = 'player_b_win' then 1 else 0 end,
      draws = draws + case when p_outcome = 'draw' then 1 else 0 end,
      last_match_at = v_completed_at, updated_at = v_completed_at
    where user_id = p_player_a_id and target = p_target;
    update public.pvp_ratings set
      rating = v_after_b, rated_matches = rated_matches + 1,
      wins = wins + case when p_outcome = 'player_b_win' then 1 else 0 end,
      losses = losses + case when p_outcome = 'player_a_win' then 1 else 0 end,
      draws = draws + case when p_outcome = 'draw' then 1 else 0 end,
      last_match_at = v_completed_at, updated_at = v_completed_at
    where user_id = p_player_b_id and target = p_target;

    insert into public.pvp_rating_events(
      match_result_id, user_id, opponent_user_id, target, rating_before,
      expected_score, actual_score, rating_delta, rating_after, created_at
    ) values
      (v_result.id, p_player_a_id, p_player_b_id, p_target, v_rating_a, v_expected_a, v_score_a, v_delta_a, v_after_a, v_completed_at),
      (v_result.id, p_player_b_id, p_player_a_id, p_target, v_rating_b, v_expected_b, v_score_b, v_delta_b, v_after_b, v_completed_at);

    update public.profiles set
      total_matches = total_matches + 1,
      wins = wins + case when p_outcome = 'player_a_win' then 1 else 0 end,
      losses = losses + case when p_outcome = 'player_b_win' then 1 else 0 end,
      draws = draws + case when p_outcome = 'draw' then 1 else 0 end,
      winrate = round((wins + case when p_outcome = 'player_a_win' then 1 else 0 end)::numeric / (total_matches + 1)::numeric * 100, 2),
      coins = coins + v_coins_delta_a, updated_at = v_completed_at
    where id = p_player_a_id returning coins into v_coin_balance;
    insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after, created_at)
    values (p_player_a_id, v_coins_delta_a, 'match_reward', p_room_id, 'match:' || p_room_id || ':player-a', v_coin_balance, v_completed_at);

    update public.profiles set
      total_matches = total_matches + 1,
      wins = wins + case when p_outcome = 'player_b_win' then 1 else 0 end,
      losses = losses + case when p_outcome = 'player_a_win' then 1 else 0 end,
      draws = draws + case when p_outcome = 'draw' then 1 else 0 end,
      winrate = round((wins + case when p_outcome = 'player_b_win' then 1 else 0 end)::numeric / (total_matches + 1)::numeric * 100, 2),
      coins = coins + v_coins_delta_b, updated_at = v_completed_at
    where id = p_player_b_id returning coins into v_coin_balance;
    insert into public.coin_transactions(user_id, delta, reason, reference_id, idempotency_key, balance_after, created_at)
    values (p_player_b_id, v_coins_delta_b, 'match_reward', p_room_id, 'match:' || p_room_id || ':player-b', v_coin_balance, v_completed_at);
  end if;

  if v_normal_public then
    v_daily_a := public.apply_daily_mission(p_player_a_id, 'daily_pvp', p_mode, p_room_id, v_completed_at);
    v_streak_a := public.apply_streak_activity(p_player_a_id, p_mode, p_room_id, v_completed_at);
    perform public.record_hired_pass_activity(p_player_a_id, 'public_pvp_completed', p_room_id, v_completed_at);
    if p_mode = 'ranked' then
      perform public.record_hired_pass_activity(p_player_a_id, 'ranked_completed', p_room_id, v_completed_at);
      if p_winner_user_id = p_player_a_id then perform public.record_hired_pass_activity(p_player_a_id, 'ranked_won', p_room_id, v_completed_at); end if;
    end if;
    if (v_streak_a ->> 'created')::boolean then perform public.record_hired_pass_activity(p_player_a_id, 'streak_day_created', p_room_id, v_completed_at); end if;

    if p_player_b_id is not null then
      v_daily_b := public.apply_daily_mission(p_player_b_id, 'daily_pvp', p_mode, p_room_id, v_completed_at);
      v_streak_b := public.apply_streak_activity(p_player_b_id, p_mode, p_room_id, v_completed_at);
      perform public.record_hired_pass_activity(p_player_b_id, 'public_pvp_completed', p_room_id, v_completed_at);
      if p_mode = 'ranked' then
        perform public.record_hired_pass_activity(p_player_b_id, 'ranked_completed', p_room_id, v_completed_at);
        if p_winner_user_id = p_player_b_id then perform public.record_hired_pass_activity(p_player_b_id, 'ranked_won', p_room_id, v_completed_at); end if;
      end if;
      if (v_streak_b ->> 'created')::boolean then perform public.record_hired_pass_activity(p_player_b_id, 'streak_day_created', p_room_id, v_completed_at); end if;
    end if;
  end if;

  return jsonb_build_object(
    'persisted', true, 'matchResultId', v_result.id,
    'pvpRatingDeltaA', v_delta_a, 'pvpRatingDeltaB', v_delta_b,
    'pvpRatingAfterA', v_after_a, 'pvpRatingAfterB', v_after_b,
    'coinsDeltaA', v_coins_delta_a, 'coinsDeltaB', case when v_is_bot then 0 else v_coins_delta_b end,
    'progressionApplied', v_is_rated or v_normal_public,
    'dailyMissionA', v_daily_a, 'dailyMissionB', v_daily_b,
    'streakA', v_streak_a, 'streakB', v_streak_b
  );
end;
$$;

-- Rebuildable derived history. Raw match results are never modified.
create or replace function public.rebuild_pvp_ratings_v1()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
  v_rating_a integer;
  v_rating_b integer;
  v_after_a integer;
  v_after_b integer;
  v_delta_a integer;
  v_delta_b integer;
  v_expected_a numeric;
  v_score_a numeric;
  v_processed integer := 0;
begin
  perform pg_advisory_xact_lock(hashtext('rebuild_pvp_ratings_v1'));
  delete from public.pvp_rating_events where algorithm_version = 'elo-v1';
  delete from public.pvp_ratings where algorithm_version = 'elo-v1';

  for v_match in
    select * from public.match_results
    where mode = 'ranked' and target in ('cpns', 'bumn')
      and player_a_id is not null and player_b_id is not null
      and not (reason = 'disconnect' and winner_user_id is null and loser_user_id is null)
    order by ended_at, id
  loop
    insert into public.pvp_ratings(user_id, target) values
      (v_match.player_a_id, v_match.target), (v_match.player_b_id, v_match.target)
    on conflict (user_id, target) do nothing;
    select rating into v_rating_a from public.pvp_ratings where user_id = v_match.player_a_id and target = v_match.target;
    select rating into v_rating_b from public.pvp_ratings where user_id = v_match.player_b_id and target = v_match.target;
    v_expected_a := 1 / (1 + power(10::numeric, (v_rating_b - v_rating_a)::numeric / 400));
    v_score_a := case v_match.outcome when 'player_a_win' then 1 when 'draw' then 0.5 else 0 end;
    v_delta_a := round(32 * (v_score_a - v_expected_a));
    v_delta_b := -v_delta_a;
    v_after_a := greatest(0, v_rating_a + v_delta_a);
    v_after_b := greatest(0, v_rating_b + v_delta_b);
    v_delta_a := v_after_a - v_rating_a;
    v_delta_b := v_after_b - v_rating_b;

    update public.pvp_ratings set rating = v_after_a, rated_matches = rated_matches + 1,
      wins = wins + case when v_match.outcome = 'player_a_win' then 1 else 0 end,
      losses = losses + case when v_match.outcome = 'player_b_win' then 1 else 0 end,
      draws = draws + case when v_match.outcome = 'draw' then 1 else 0 end,
      last_match_at = v_match.ended_at, updated_at = clock_timestamp()
    where user_id = v_match.player_a_id and target = v_match.target;
    update public.pvp_ratings set rating = v_after_b, rated_matches = rated_matches + 1,
      wins = wins + case when v_match.outcome = 'player_b_win' then 1 else 0 end,
      losses = losses + case when v_match.outcome = 'player_a_win' then 1 else 0 end,
      draws = draws + case when v_match.outcome = 'draw' then 1 else 0 end,
      last_match_at = v_match.ended_at, updated_at = clock_timestamp()
    where user_id = v_match.player_b_id and target = v_match.target;

    insert into public.pvp_rating_events(match_result_id, user_id, opponent_user_id, target,
      rating_before, expected_score, actual_score, rating_delta, rating_after, created_at)
    values
      (v_match.id, v_match.player_a_id, v_match.player_b_id, v_match.target, v_rating_a, v_expected_a, v_score_a, v_delta_a, v_after_a, v_match.ended_at),
      (v_match.id, v_match.player_b_id, v_match.player_a_id, v_match.target, v_rating_b, 1-v_expected_a, 1-v_score_a, v_delta_b, v_after_b, v_match.ended_at);
    v_processed := v_processed + 1;
  end loop;
  return jsonb_build_object('algorithmVersion', 'elo-v1', 'matchesProcessed', v_processed);
end;
$$;

create or replace function public.ingest_pvp_learning_evidence(
  p_match_result_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_match public.match_results%rowtype;
  v_log record;
  v_attempt_id uuid;
  v_existing_hash text;
  v_payload_hash text;
  v_classifier_hash text;
  v_complete boolean;
  v_seen_before boolean;
  v_inserted integer := 0;
  v_existing integer := 0;
begin
  select * into v_match from public.match_results where id = p_match_result_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND: match result';
  end if;
  if v_match.target not in ('cpns', 'bumn') or v_match.mode not in ('casual', 'ranked', 'private') then
    return jsonb_build_object('matchResultId', p_match_result_id, 'inserted', 0, 'existing', 0, 'skipped', true);
  end if;

  for v_log in
    select log.* from public.match_logs log
    where log.match_result_id = p_match_result_id
      and log.player_id is not null
      and log.is_correct is not null
      and log.action_type in ('play_card', 'timeout')
    order by log.action_timestamp, log.id
  loop
    v_complete := v_log.question_revision_id is not null
      and v_log.taxonomy_version_id is not null
      and nullif(btrim(v_log.skill_id), '') is not null
      and nullif(btrim(v_log.category_snapshot), '') is not null
      and v_log.difficulty_snapshot in ('easy', 'medium', 'hard')
      and v_log.time_limit_ms is not null
      and v_log.opened_at is not null
      and v_log.answered_at is not null
      and v_log.response_time_ms is not null;
    v_seen_before := case when v_log.question_revision_id is null then null else exists(
      select 1 from public.learning_attempts prior
      where prior.user_id = v_log.player_id
        and prior.question_revision_id = v_log.question_revision_id
        and (prior.source_event_at < v_log.action_timestamp
          or (prior.source_event_at = v_log.action_timestamp and prior.source_attempt_key < 'pvp:' || v_log.id::text))
    ) end;

    v_payload_hash := encode(extensions.digest(jsonb_build_object(
      'matchResultId', p_match_result_id, 'matchLogId', v_log.id,
      'userId', v_log.player_id, 'target', v_match.target, 'mode', v_match.mode,
      'questionId', v_log.question_id, 'questionRevisionId', v_log.question_revision_id,
      'taxonomyVersionId', v_log.taxonomy_version_id, 'skillId', v_log.skill_id,
      'selectedOptionIndex', v_log.selected_option_index, 'isCorrect', v_log.is_correct,
      'timedOut', v_log.action_type = 'timeout', 'actionTimestamp', v_log.action_timestamp
    )::text, 'sha256'), 'hex');

    v_attempt_id := null;
    insert into public.learning_attempts(
      source, source_attempt_key, source_payload_hash, data_fidelity,
      user_id, target, source_session_key, pvp_mode,
      question_id, question_revision_id, taxonomy_version_id, skill_id,
      category, subcategory, difficulty, expected_time_ms, standard_time_limit_ms,
      selected_option_index, is_correct, hint_requested, timed_out,
      first_attempt, seen_before, exposure_count_before,
      opened_at, answered_at, deadline_at, client_active_response_time_ms,
      server_elapsed_time_ms, effective_response_time_ms,
      timing_invalidity_reason, source_event_at
    ) values (
      'pvp', 'pvp:' || v_log.id::text, v_payload_hash,
      case when v_complete then 'v2_complete' else 'legacy_pvp' end,
      v_log.player_id, v_match.target, p_match_result_id::text, v_match.mode,
      v_log.question_id, v_log.question_revision_id, v_log.taxonomy_version_id, v_log.skill_id,
      v_log.category_snapshot, v_log.subcategory_snapshot, v_log.difficulty_snapshot,
      v_log.expected_time_ms, v_log.time_limit_ms,
      v_log.selected_option_index, v_log.is_correct, false, v_log.action_type = 'timeout',
      case when v_seen_before is null then null else not v_seen_before end,
      v_seen_before,
      case when v_log.question_revision_id is null then null else (
        select count(*)::integer from public.learning_attempts prior
        where prior.user_id = v_log.player_id and prior.question_revision_id = v_log.question_revision_id
          and prior.source_event_at < v_log.action_timestamp
      ) end,
      v_log.opened_at, coalesce(v_log.answered_at, v_log.action_timestamp),
      case when v_log.opened_at is null or v_log.time_limit_ms is null then null
        else v_log.opened_at + make_interval(secs => v_log.time_limit_ms::numeric / 1000) end,
      v_log.response_time_ms, v_log.response_time_ms,
      case when v_complete then v_log.response_time_ms else null end,
      case when v_complete then null else 'pvp_metadata_or_timing_incomplete' end,
      v_log.action_timestamp
    ) on conflict (source, source_attempt_key) do nothing returning id into v_attempt_id;

    if v_attempt_id is null then
      select attempt.id, attempt.source_payload_hash into v_attempt_id, v_existing_hash
      from public.learning_attempts attempt
      where attempt.source = 'pvp' and attempt.source_attempt_key = 'pvp:' || v_log.id::text;
      if v_existing_hash <> v_payload_hash then
        raise exception using errcode = 'P0001', message = 'CONFLICT: canonical PvP attempt payload differs';
      end if;
      v_existing := v_existing + 1;
    else
      v_inserted := v_inserted + 1;
    end if;

    v_classifier_hash := encode(extensions.digest(jsonb_build_object(
      'attemptId', v_attempt_id, 'classificationVersion', 'evidence-v1',
      'source', 'pvp', 'competitionContextSeparate', true, 'complete', v_complete
    )::text, 'sha256'), 'hex');
    insert into public.learning_attempt_classifications(
      attempt_id, classification_version, classifier_input_hash,
      valid_for_activity_accuracy, valid_for_independent_accuracy,
      valid_for_unseen_independent_accuracy, valid_for_assisted_accuracy,
      valid_for_pace_analytics, valid_for_fluency_baseline,
      valid_for_retention, exclusion_reasons, classified_at
    ) values (
      v_attempt_id, 'evidence-v1', v_classifier_hash,
      true, false, false, false, v_complete, false, false,
      case when v_complete then array['competition_context_separate']::text[] else
        array['competition_context_separate', 'revision_or_skill_unknown', 'timing_eligibility_unknown']::text[] end,
      v_log.action_timestamp
    ) on conflict (attempt_id, classification_version) do nothing;
  end loop;

  return jsonb_build_object(
    'matchResultId', p_match_result_id, 'inserted', v_inserted,
    'existing', v_existing, 'skipped', false
  );
end;
$$;

revoke all on function public.get_target_leaderboard_page(uuid, integer, integer) from public, anon, authenticated;
revoke all on function public.get_target_leaderboard_rank(uuid) from public, anon, authenticated;
revoke all on function public.rebuild_pvp_ratings_v1() from public, anon, authenticated;
revoke all on function public.ingest_pvp_learning_evidence(uuid) from public, anon, authenticated;
revoke all on function public.apply_daily_mission(uuid, text, text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.finalize_match_result(text, text, text, uuid, uuid, uuid, uuid, text, text, integer, integer, integer, integer, integer, timestamptz) from public, anon, authenticated;
grant execute on function public.get_target_leaderboard_page(uuid, integer, integer) to service_role;
grant execute on function public.get_target_leaderboard_rank(uuid) to service_role;
grant execute on function public.rebuild_pvp_ratings_v1() to service_role;
grant execute on function public.ingest_pvp_learning_evidence(uuid) to service_role;
grant execute on function public.apply_daily_mission(uuid, text, text, text, timestamptz) to service_role;
grant execute on function public.finalize_match_result(text, text, text, uuid, uuid, uuid, uuid, text, text, integer, integer, integer, integer, integer, timestamptz) to service_role;

select public.rebuild_pvp_ratings_v1();

commit;
