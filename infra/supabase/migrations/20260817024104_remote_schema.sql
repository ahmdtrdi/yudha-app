
\restrict GhSyYr7p949Qgg16DmVC4ENAD4yZ9tcm4z6S36kNYOJH7RVOi5XFvm3Y8tKmFeq


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."claim_hired_pass_reward"("p_user_id" "uuid", "p_reward_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_reward public.hired_pass_rewards%rowtype;
  v_points integer := 0;
  v_expires_at timestamptz;
  v_balance integer;
begin
  select reward.* into v_reward
  from public.hired_pass_rewards reward
  join public.hired_pass_seasons season on season.id = reward.season_id
  where reward.id = p_reward_id
    and reward.is_active
    and season.is_active
    and now() >= season.starts_at
    and now() < season.ends_at;

  if not found then
    raise exception 'Hired Pass reward is not available.';
  end if;

  select
    coalesce(progress.pass_points, 0),
    profile.hired_pass_expires_at,
    profile.coins
  into v_points, v_expires_at, v_balance
  from public.profiles profile
  left join public.user_hired_pass_progress progress
    on progress.user_id = profile.id
    and progress.season_id = v_reward.season_id
  where profile.id = p_user_id
  for update of profile;

  if not found then
    raise exception 'Profile not found.';
  end if;
  if v_points < v_reward.points_required then
    raise exception 'Not enough Hired Pass points.';
  end if;
  if v_reward.track = 'premium'
    and (v_expires_at is null or v_expires_at <= now()) then
    raise exception 'An active Hired Pass entitlement is required.';
  end if;

  insert into public.user_hired_pass_reward_claims
    (user_id, reward_id, coins_awarded, item_id)
  values
    (p_user_id, v_reward.id, v_reward.coins_reward, v_reward.item_id)
  on conflict (user_id, reward_id) do nothing;

  if not found then
    return jsonb_build_object(
      'claimed', false,
      'reason', 'already_claimed',
      'rewardId', v_reward.id,
      'coins', v_balance
    );
  end if;

  if v_reward.coins_reward > 0 then
    update public.profiles
    set coins = coins + v_reward.coins_reward
    where id = p_user_id
    returning coins into v_balance;

    insert into public.coin_transactions
      (user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values
      (
        p_user_id,
        v_reward.coins_reward,
        'hired_pass_reward',
        v_reward.id,
        'hired-pass-reward:' || v_reward.id,
        v_balance
      );
  end if;

  if v_reward.item_id is not null then
    insert into public.user_inventory (user_id, item_id, source, source_ref)
    values (p_user_id, v_reward.item_id, 'hired_pass', v_reward.id)
    on conflict (user_id, item_id) do nothing;
  end if;

  return jsonb_build_object(
    'claimed', true,
    'rewardId', v_reward.id,
    'coins', v_balance,
    'itemId', v_reward.item_id
  );
end;
$$;


ALTER FUNCTION "public"."claim_hired_pass_reward"("p_user_id" "uuid", "p_reward_id" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."match_results" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "room_id" "text" NOT NULL,
    "mode" "text" DEFAULT 'player'::"text" NOT NULL,
    "player_a_id" "uuid",
    "player_b_id" "uuid",
    "winner_user_id" "uuid",
    "loser_user_id" "uuid",
    "outcome" "text" NOT NULL,
    "reason" "text" NOT NULL,
    "player_a_hp" integer NOT NULL,
    "player_b_hp" integer NOT NULL,
    "player_a_points" integer NOT NULL,
    "player_b_points" integer NOT NULL,
    "rating_delta_a" integer DEFAULT 0 NOT NULL,
    "rating_delta_b" integer DEFAULT 0 NOT NULL,
    "coins_delta_a" integer DEFAULT 0 NOT NULL,
    "coins_delta_b" integer DEFAULT 0 NOT NULL,
    "duration_seconds" integer,
    "started_at" timestamp with time zone,
    "ended_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "target" "text" DEFAULT 'cpns'::"text" NOT NULL,
    CONSTRAINT "match_results_duration_check" CHECK ((("duration_seconds" IS NULL) OR ("duration_seconds" >= 0))),
    CONSTRAINT "match_results_hp_check" CHECK (((("player_a_hp" >= 0) AND ("player_a_hp" <= 100)) AND (("player_b_hp" >= 0) AND ("player_b_hp" <= 100)))),
    CONSTRAINT "match_results_loser_is_player_check" CHECK ((("loser_user_id" IS NULL) OR ("loser_user_id" = "player_a_id") OR ("loser_user_id" = "player_b_id"))),
    CONSTRAINT "match_results_mode_check" CHECK (("mode" = ANY (ARRAY['ranked'::"text", 'casual'::"text", 'bot'::"text"]))),
    CONSTRAINT "match_results_outcome_check" CHECK (("outcome" = ANY (ARRAY['player_a_win'::"text", 'player_b_win'::"text", 'draw'::"text"]))),
    CONSTRAINT "match_results_points_check" CHECK ((("player_a_points" >= 0) AND ("player_b_points" >= 0))),
    CONSTRAINT "match_results_reason_check" CHECK (("reason" = ANY (ARRAY['hp_zero'::"text", 'round_timeout'::"text", 'surrender'::"text", 'question_exhaustion'::"text", 'draw'::"text", 'disconnect'::"text"]))),
    CONSTRAINT "match_results_target_check" CHECK (("target" = ANY (ARRAY['cpns'::"text", 'bumn'::"text"]))),
    CONSTRAINT "match_results_winner_is_player_check" CHECK ((("winner_user_id" IS NULL) OR ("winner_user_id" = "player_a_id") OR ("winner_user_id" = "player_b_id"))),
    CONSTRAINT "match_results_winner_loser_different_check" CHECK ((("winner_user_id" IS NULL) OR ("loser_user_id" IS NULL) OR ("winner_user_id" <> "loser_user_id")))
);


ALTER TABLE "public"."match_results" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finalize_match_result"("p_room_id" "uuid", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_outcome" "text", "p_final_hp_a" integer, "p_final_hp_b" integer, "p_score_a" integer, "p_score_b" integer, "p_reason" "text", "p_is_bot_match" boolean DEFAULT false) RETURNS "public"."match_results"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_result match_results;
  v_rating_delta_a int;
  v_rating_delta_b int;
  v_coins_delta_a int;
  v_coins_delta_b int;
begin
  -- 1. Compute deltas based on outcome (win/lose/draw/surrender)
  -- 2. Insert into match_results
  -- 3. Update profiles for player_a and (if not bot) player_b
  -- 4. Return the inserted row
  -- (full logic filled in during implementation — keep this function
  --  the single source of truth for reward math so app-side and
  --  game-side never disagree)
end;
$$;


ALTER FUNCTION "public"."finalize_match_result"("p_room_id" "uuid", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_outcome" "text", "p_final_hp_a" integer, "p_final_hp_b" integer, "p_score_a" integer, "p_score_b" integer, "p_reason" "text", "p_is_bot_match" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finalize_match_result"("p_room_id" "text", "p_mode" "text", "p_target" "text", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_winner_user_id" "uuid", "p_loser_user_id" "uuid", "p_outcome" "text", "p_reason" "text", "p_player_a_hp" integer, "p_player_b_hp" integer, "p_player_a_points" integer, "p_player_b_points" integer, "p_duration_seconds" integer DEFAULT NULL::integer, "p_started_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."finalize_match_result"("p_room_id" "text", "p_mode" "text", "p_target" "text", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_winner_user_id" "uuid", "p_loser_user_id" "uuid", "p_outcome" "text", "p_reason" "text", "p_player_a_hp" integer, "p_player_b_hp" integer, "p_player_a_points" integer, "p_player_b_points" integer, "p_duration_seconds" integer, "p_started_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_practice_analytics"("p_user_id" "uuid") RETURNS TABLE("category" "text", "subcategory" "text", "total_answered" integer, "total_correct" integer, "avg_response_time_ms" numeric)
    LANGUAGE "sql" STABLE
    AS $$
      select q.category, q.subcategory,
             count(*) as total_answered,
             count(*) filter (where pa.is_correct) as total_correct,
             avg(pa.response_time_ms) as avg_response_time_ms
      from practice_answers pa
      join questions q on q.id = pa.question_id
      where pa.user_id = p_user_id
      group by q.category, q.subcategory;
    $$;


ALTER FUNCTION "public"."get_practice_analytics"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grant_beta_credit"("p_user_id" "uuid", "p_idempotency_key" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_balance integer;
  v_existing public.coin_transactions%rowtype;
begin
  if nullif(btrim(p_idempotency_key), '') is null then
    raise exception 'Idempotency key is required.';
  end if;

  select * into v_existing
  from public.coin_transactions
  where user_id = p_user_id
    and idempotency_key = 'beta-credit:' || p_idempotency_key;

  if found then
    return jsonb_build_object(
      'credited', false,
      'replayed', true,
      'coins', v_existing.balance_after
    );
  end if;

  update public.profiles
  set coins = coins + 100
  where id = p_user_id
  returning coins into v_balance;

  if not found then
    raise exception 'Profile not found.';
  end if;

  insert into public.coin_transactions
    (user_id, delta, reason, reference_id, idempotency_key, balance_after)
  values
    (
      p_user_id,
      100,
      'beta_credit',
      p_idempotency_key,
      'beta-credit:' || p_idempotency_key,
      v_balance
    );

  return jsonb_build_object(
    'credited', true,
    'replayed', false,
    'coins', v_balance
  );
end;
$$;


ALTER FUNCTION "public"."grant_beta_credit"("p_user_id" "uuid", "p_idempotency_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.profiles (
    id,
    username,
    full_name,
    target,
    equipped_avatar_id,
    equipped_arena_id,
    equipped_tower_id
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'username',
      split_part(new.email, '@', 1),
      'player'
    ),
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'display_name'), '')
    ),
    new.raw_user_meta_data ->> 'target',
    'character-basic-squire',
    'arena-cpns',
    'tower-garda-biru'
  )
  on conflict (id) do nothing;

  insert into public.user_inventory (user_id, item_id, source, source_ref)
  select new.id, item.id, 'starter', 'signup'
  from public.store_items item
  where item.coin_price = 0 and item.is_active
  on conflict (user_id, item_id) do nothing;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purchase_store_item"("p_user_id" "uuid", "p_item_id" "text", "p_idempotency_key" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.store_items%rowtype;
  v_existing public.store_purchases%rowtype;
  v_purchase_id uuid;
  v_balance integer;
begin
  if nullif(btrim(p_idempotency_key), '') is null then
    raise exception 'Idempotency key is required.';
  end if;

  select * into v_existing
  from public.store_purchases
  where user_id = p_user_id and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.item_id <> p_item_id then
      raise exception 'Idempotency key was already used for another item.';
    end if;
    select coins into v_balance from public.profiles where id = p_user_id;
    return jsonb_build_object(
      'purchased', false,
      'replayed', true,
      'purchaseId', v_existing.id,
      'itemId', v_existing.item_id,
      'coins', v_balance
    );
  end if;

  select * into v_item
  from public.store_items
  where id = p_item_id and is_active
  for update;

  if not found then
    raise exception 'Store item is not available.';
  end if;
  if v_item.is_pass_exclusive then
    raise exception 'Store item is only available from Hired Pass.';
  end if;
  if exists (
    select 1 from public.user_inventory
    where user_id = p_user_id and item_id = p_item_id
  ) then
    raise exception 'Store item is already owned.';
  end if;

  select coins into v_balance
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;
  if v_balance < v_item.coin_price then
    raise exception 'Insufficient Y-Coin balance.';
  end if;

  update public.profiles
  set coins = coins - v_item.coin_price
  where id = p_user_id
  returning coins into v_balance;

  insert into public.store_purchases
    (user_id, item_id, idempotency_key, price_paid)
  values
    (p_user_id, p_item_id, p_idempotency_key, v_item.coin_price)
  returning id into v_purchase_id;

  insert into public.user_inventory (user_id, item_id, source, source_ref)
  values (p_user_id, p_item_id, 'purchase', v_purchase_id::text);

  if v_item.coin_price > 0 then
    insert into public.coin_transactions
      (user_id, delta, reason, reference_id, idempotency_key, balance_after)
    values
      (
        p_user_id,
        -v_item.coin_price,
        'store_purchase',
        v_purchase_id::text,
        'store-purchase:' || p_idempotency_key,
        v_balance
      );
  end if;

  return jsonb_build_object(
    'purchased', true,
    'replayed', false,
    'purchaseId', v_purchase_id,
    'itemId', p_item_id,
    'coins', v_balance
  );
end;
$$;


ALTER FUNCTION "public"."purchase_store_item"("p_user_id" "uuid", "p_item_id" "text", "p_idempotency_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_hired_pass_activity"("p_user_id" "uuid", "p_event_type" "text", "p_source_id" "text", "p_occurred_at" timestamp with time zone DEFAULT "now"()) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mission public.hired_pass_missions%rowtype;
  v_period_start date;
  v_event_id uuid;
  v_progress_count integer;
  v_awarded_at timestamptz;
  v_points_awarded integer := 0;
  v_season_id text;
  v_total_points integer := 0;
begin
  if p_event_type not in ('practice_completed', 'battle_completed', 'interview_completed') then
    raise exception 'Unsupported Hired Pass event type.';
  end if;
  if nullif(btrim(p_source_id), '') is null then
    raise exception 'Hired Pass source ID is required.';
  end if;

  for v_mission in
    select mission.*
    from public.hired_pass_missions mission
    join public.hired_pass_seasons season on season.id = mission.season_id
    where mission.event_type = p_event_type
      and mission.is_active
      and season.is_active
      and p_occurred_at >= season.starts_at
      and p_occurred_at < season.ends_at
  loop
    v_season_id := v_mission.season_id;
    v_event_id := null;
    v_period_start := case v_mission.cadence
      when 'daily' then (p_occurred_at at time zone 'UTC')::date
      when 'weekly' then date_trunc('week', p_occurred_at at time zone 'UTC')::date
      else (
        select (starts_at at time zone 'UTC')::date
        from public.hired_pass_seasons
        where id = v_mission.season_id
      )
    end;

    insert into public.hired_pass_activity_events
      (user_id, mission_id, source_type, source_id, period_start)
    values
      (p_user_id, v_mission.id, p_event_type, p_source_id, v_period_start)
    on conflict (user_id, mission_id, source_type, source_id) do nothing
    returning id into v_event_id;

    if v_event_id is null then
      continue;
    end if;

    insert into public.user_hired_pass_progress (user_id, season_id)
    values (p_user_id, v_mission.season_id)
    on conflict (user_id, season_id) do nothing;

    insert into public.user_hired_pass_mission_progress
      (user_id, mission_id, period_start, progress_count, updated_at)
    values
      (p_user_id, v_mission.id, v_period_start, 1, now())
    on conflict (user_id, mission_id, period_start) do update set
      progress_count = least(
        v_mission.target_count,
        public.user_hired_pass_mission_progress.progress_count + 1
      ),
      updated_at = now()
    returning progress_count, points_awarded_at
      into v_progress_count, v_awarded_at;

    if v_progress_count >= v_mission.target_count and v_awarded_at is null then
      update public.user_hired_pass_mission_progress
      set
        completed_at = coalesce(completed_at, now()),
        points_awarded_at = now(),
        updated_at = now()
      where user_id = p_user_id
        and mission_id = v_mission.id
        and period_start = v_period_start
        and points_awarded_at is null
      returning points_awarded_at into v_awarded_at;

      if found then
        update public.user_hired_pass_progress
        set
          pass_points = pass_points + v_mission.points_reward,
          updated_at = now()
        where user_id = p_user_id and season_id = v_mission.season_id;
        v_points_awarded := v_points_awarded + v_mission.points_reward;
      end if;
    end if;
  end loop;

  if v_season_id is not null then
    select pass_points into v_total_points
    from public.user_hired_pass_progress
    where user_id = p_user_id and season_id = v_season_id;
  end if;

  return jsonb_build_object(
    'seasonId', v_season_id,
    'pointsAwarded', v_points_awarded,
    'passPoints', coalesce(v_total_points, 0)
  );
end;
$$;


ALTER FUNCTION "public"."record_hired_pass_activity"("p_user_id" "uuid", "p_event_type" "text", "p_source_id" "text", "p_occurred_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_interview_hired_pass_completion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.record_hired_pass_activity(
    new.user_id,
    'interview_completed',
    new.id::text,
    new.updated_at
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."record_interview_hired_pass_completion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_practice_hired_pass_completion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.record_hired_pass_activity(
    new.user_id,
    'practice_completed',
    new.id::text,
    new.finished_at
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."record_practice_hired_pass_completion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_profile_loadout"("p_user_id" "uuid", "p_avatar_id" "text" DEFAULT NULL::"text", "p_tower_id" "text" DEFAULT NULL::"text", "p_arena_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_avatar_id is null and p_tower_id is null and p_arena_id is null then
    raise exception 'At least one loadout field is required.';
  end if;

  if p_avatar_id is not null and not exists (
    select 1
    from public.user_inventory inventory
    join public.store_items item on item.id = inventory.item_id
    where inventory.user_id = p_user_id
      and item.id = p_avatar_id
      and item.type = 'character_skin'
      and item.is_active
  ) then
    raise exception 'Character is not owned or available.';
  end if;

  if p_tower_id is not null and not exists (
    select 1
    from public.user_inventory inventory
    join public.store_items item on item.id = inventory.item_id
    where inventory.user_id = p_user_id
      and item.id = p_tower_id
      and item.type = 'tower'
      and item.is_active
  ) then
    raise exception 'Tower is not owned or available.';
  end if;

  if p_arena_id is not null and not exists (
    select 1
    from public.user_inventory inventory
    join public.store_items item on item.id = inventory.item_id
    where inventory.user_id = p_user_id
      and item.id = p_arena_id
      and item.type = 'arena'
      and item.is_active
  ) then
    raise exception 'Arena is not owned or available.';
  end if;

  update public.profiles set
    equipped_avatar_id = coalesce(p_avatar_id, equipped_avatar_id),
    equipped_tower_id = coalesce(p_tower_id, equipped_tower_id),
    equipped_arena_id = coalesce(p_arena_id, equipped_arena_id)
  where id = p_user_id;

  if not found then
    raise exception 'Profile not found.';
  end if;

  return (
    select jsonb_build_object(
      'characterId', equipped_avatar_id,
      'towerId', equipped_tower_id,
      'arenaId', equipped_arena_id
    )
    from public.profiles
    where id = p_user_id
  );
end;
$$;


ALTER FUNCTION "public"."set_profile_loadout"("p_user_id" "uuid", "p_avatar_id" "text", "p_tower_id" "text", "p_arena_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."coin_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "delta" integer NOT NULL,
    "reason" "text" NOT NULL,
    "reference_id" "text",
    "idempotency_key" "text" NOT NULL,
    "balance_after" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "coin_transactions_balance_after_check" CHECK (("balance_after" >= 0)),
    CONSTRAINT "coin_transactions_delta_check" CHECK (("delta" <> 0)),
    CONSTRAINT "coin_transactions_reason_check" CHECK (("reason" = ANY (ARRAY['match_reward'::"text", 'store_purchase'::"text", 'hired_pass_reward'::"text", 'beta_credit'::"text", 'admin'::"text"])))
);


ALTER TABLE "public"."coin_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hired_pass_activity_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "mission_id" "text" NOT NULL,
    "source_type" "text" NOT NULL,
    "source_id" "text" NOT NULL,
    "period_start" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."hired_pass_activity_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hired_pass_missions" (
    "id" "text" NOT NULL,
    "season_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "cadence" "text" NOT NULL,
    "target_count" integer NOT NULL,
    "points_reward" integer NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hired_pass_missions_cadence_check" CHECK (("cadence" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'season'::"text"]))),
    CONSTRAINT "hired_pass_missions_event_type_check" CHECK (("event_type" = ANY (ARRAY['practice_completed'::"text", 'battle_completed'::"text", 'interview_completed'::"text"]))),
    CONSTRAINT "hired_pass_missions_points_reward_check" CHECK (("points_reward" > 0)),
    CONSTRAINT "hired_pass_missions_target_count_check" CHECK (("target_count" > 0))
);


ALTER TABLE "public"."hired_pass_missions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hired_pass_rewards" (
    "id" "text" NOT NULL,
    "season_id" "text" NOT NULL,
    "track" "text" NOT NULL,
    "points_required" integer NOT NULL,
    "label" "text" NOT NULL,
    "coins_reward" integer DEFAULT 0 NOT NULL,
    "item_id" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hired_pass_rewards_check" CHECK ((("coins_reward" > 0) OR ("item_id" IS NOT NULL))),
    CONSTRAINT "hired_pass_rewards_coins_reward_check" CHECK (("coins_reward" >= 0)),
    CONSTRAINT "hired_pass_rewards_points_required_check" CHECK (("points_required" >= 0)),
    CONSTRAINT "hired_pass_rewards_track_check" CHECK (("track" = ANY (ARRAY['free'::"text", 'premium'::"text"])))
);


ALTER TABLE "public"."hired_pass_rewards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hired_pass_seasons" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hired_pass_seasons_check" CHECK (("ends_at" > "starts_at"))
);


ALTER TABLE "public"."hired_pass_seasons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."interview_company_contexts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "company_id" "text" NOT NULL,
    "category" "text" NOT NULL,
    "content" "text" NOT NULL,
    "priority" integer DEFAULT 100 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."interview_company_contexts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."interview_company_profiles" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "content_version" "text" DEFAULT 'v1'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."interview_company_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."interview_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "company_id" "text" NOT NULL,
    "target_role" "text" NOT NULL,
    "mode" "text" NOT NULL,
    "language" "text" DEFAULT 'id'::"text" NOT NULL,
    "response_style" "text" DEFAULT 'text'::"text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "context_snapshot" "jsonb" NOT NULL,
    "rolling_summary" "text" DEFAULT ''::"text" NOT NULL,
    "final_summary" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "interview_sessions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."interview_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."interview_turns" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "content" "text" NOT NULL,
    "idempotency_key" "text",
    "parent_turn_id" "uuid",
    "processing_status" "text",
    "evaluation" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "interview_turns_processing_status_check" CHECK (("processing_status" = ANY (ARRAY['pending'::"text", 'completed'::"text", 'failed'::"text"]))),
    CONSTRAINT "interview_turns_role_check" CHECK (("role" = ANY (ARRAY['question'::"text", 'answer'::"text"])))
);


ALTER TABLE "public"."interview_turns" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."match_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "match_result_id" "uuid" NOT NULL,
    "player_id" "uuid",
    "question_id" "uuid",
    "card_id" "text",
    "action_type" "text" DEFAULT 'play_card'::"text" NOT NULL,
    "selected_option_index" integer,
    "player_answer" "text",
    "is_correct" boolean,
    "effect" "text" DEFAULT 'none'::"text" NOT NULL,
    "effect_value" integer DEFAULT 0 NOT NULL,
    "hp_before" integer,
    "hp_after" integer,
    "opponent_hp_before" integer,
    "opponent_hp_after" integer,
    "points_before" integer,
    "points_after" integer,
    "response_time_ms" integer,
    "action_timestamp" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "match_logs_action_type_check" CHECK (("action_type" = ANY (ARRAY['open_card'::"text", 'play_card'::"text", 'surrender'::"text", 'timeout'::"text"]))),
    CONSTRAINT "match_logs_effect_check" CHECK (("effect" = ANY (ARRAY['damage'::"text", 'heal'::"text", 'none'::"text"]))),
    CONSTRAINT "match_logs_effect_value_check" CHECK (("effect_value" >= 0)),
    CONSTRAINT "match_logs_hp_check" CHECK (((("hp_before" IS NULL) OR (("hp_before" >= 0) AND ("hp_before" <= 100))) AND (("hp_after" IS NULL) OR (("hp_after" >= 0) AND ("hp_after" <= 100))) AND (("opponent_hp_before" IS NULL) OR (("opponent_hp_before" >= 0) AND ("opponent_hp_before" <= 100))) AND (("opponent_hp_after" IS NULL) OR (("opponent_hp_after" >= 0) AND ("opponent_hp_after" <= 100))))),
    CONSTRAINT "match_logs_points_check" CHECK (((("points_before" IS NULL) OR ("points_before" >= 0)) AND (("points_after" IS NULL) OR ("points_after" >= 0)))),
    CONSTRAINT "match_logs_response_time_check" CHECK ((("response_time_ms" IS NULL) OR ("response_time_ms" >= 0))),
    CONSTRAINT "match_logs_selected_option_check" CHECK ((("selected_option_index" IS NULL) OR (("selected_option_index" >= 0) AND ("selected_option_index" <= 3))))
);


ALTER TABLE "public"."match_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."match_question_pool" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "match_result_id" "uuid" NOT NULL,
    "question_id" "uuid",
    "card_order" integer NOT NULL,
    "card_id" "text",
    "effect" "text" NOT NULL,
    "weight" integer DEFAULT 1 NOT NULL,
    "damage_value" integer DEFAULT 0 NOT NULL,
    "heal_value" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "match_question_pool_effect_check" CHECK (("effect" = ANY (ARRAY['damage'::"text", 'heal'::"text"]))),
    CONSTRAINT "match_question_pool_order_check" CHECK (("card_order" >= 0)),
    CONSTRAINT "match_question_pool_values_check" CHECK ((("weight" >= 1) AND ("damage_value" >= 0) AND ("heal_value" >= 0)))
);


ALTER TABLE "public"."match_question_pool" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_answers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "question_id" "uuid",
    "question_order" integer,
    "selected_option_index" integer,
    "player_answer" "text",
    "is_correct" boolean DEFAULT false NOT NULL,
    "used_hint" boolean DEFAULT false NOT NULL,
    "response_time_ms" integer,
    "answered_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "session_question_id" "uuid",
    CONSTRAINT "practice_answers_option_check" CHECK ((("selected_option_index" IS NULL) OR (("selected_option_index" >= 0) AND ("selected_option_index" <= 3)))),
    CONSTRAINT "practice_answers_question_order_check" CHECK ((("question_order" IS NULL) OR ("question_order" >= 1))),
    CONSTRAINT "practice_answers_response_time_check" CHECK ((("response_time_ms" IS NULL) OR ("response_time_ms" >= 0)))
);


ALTER TABLE "public"."practice_answers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_session_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "question_order" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "practice_session_questions_order_check" CHECK ((("question_order" >= 1) AND ("question_order" <= 10)))
);


ALTER TABLE "public"."practice_session_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "category" "text",
    "total_questions" integer DEFAULT 0 NOT NULL,
    "correct_count" integer DEFAULT 0 NOT NULL,
    "total_score" integer DEFAULT 0 NOT NULL,
    "accuracy" numeric(5,2) DEFAULT 0 NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "finished_at" timestamp with time zone,
    "target" "text" DEFAULT 'cpns'::"text" NOT NULL,
    "subcategory" "text",
    CONSTRAINT "practice_sessions_counts_check" CHECK ((("total_questions" >= 0) AND ("correct_count" >= 0) AND ("correct_count" <= "total_questions") AND ("total_score" >= 0) AND ("accuracy" >= (0)::numeric) AND ("accuracy" <= (100)::numeric))),
    CONSTRAINT "practice_sessions_target_check" CHECK (("target" = ANY (ARRAY['cpns'::"text", 'bumn'::"text", 'kedinasan'::"text"])))
);


ALTER TABLE "public"."practice_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text" NOT NULL,
    "full_name" "text",
    "rank_points" integer DEFAULT 0 NOT NULL,
    "total_matches" integer DEFAULT 0 NOT NULL,
    "wins" integer DEFAULT 0 NOT NULL,
    "losses" integer DEFAULT 0 NOT NULL,
    "winrate" numeric(5,2) DEFAULT 0 NOT NULL,
    "coins" integer DEFAULT 0 NOT NULL,
    "equipped_avatar_id" "text" DEFAULT 'character-basic-squire'::"text",
    "equipped_arena_id" "text" DEFAULT 'arena-cpns'::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "target" "text" DEFAULT 'cpns'::"text" NOT NULL,
    "equipped_tower_id" "text" DEFAULT 'tower-garda-biru'::"text",
    "hired_pass_expires_at" timestamp with time zone,
    CONSTRAINT "profiles_non_negative_stats" CHECK ((("rank_points" >= 0) AND ("total_matches" >= 0) AND ("wins" >= 0) AND ("losses" >= 0) AND ("winrate" >= (0)::numeric) AND ("winrate" <= (100)::numeric) AND ("coins" >= 0))),
    CONSTRAINT "profiles_target_check" CHECK (("target" = ANY (ARRAY['cpns'::"text", 'bumn'::"text", 'kedinasan'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category" "text" NOT NULL,
    "subcategory" "text",
    "prompt" "text" NOT NULL,
    "options" "jsonb" NOT NULL,
    "correct_option_index" integer NOT NULL,
    "explanation" "text",
    "difficulty" "text" DEFAULT 'easy'::"text" NOT NULL,
    "weight" integer DEFAULT 1 NOT NULL,
    "effect" "text" DEFAULT 'damage'::"text" NOT NULL,
    "damage_value" integer DEFAULT 10 NOT NULL,
    "heal_value" integer DEFAULT 0 NOT NULL,
    "time_limit_seconds" integer DEFAULT 30 NOT NULL,
    "hint" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "target" "text" DEFAULT 'cpns'::"text" NOT NULL,
    CONSTRAINT "questions_correct_option_check" CHECK ((("correct_option_index" >= 0) AND ("correct_option_index" <= 3))),
    CONSTRAINT "questions_difficulty_check" CHECK (("difficulty" = ANY (ARRAY['easy'::"text", 'medium'::"text", 'hard'::"text"]))),
    CONSTRAINT "questions_effect_check" CHECK (("effect" = ANY (ARRAY['damage'::"text", 'heal'::"text"]))),
    CONSTRAINT "questions_options_array_check" CHECK ((("jsonb_typeof"("options") = 'array'::"text") AND ("jsonb_array_length"("options") = 4))),
    CONSTRAINT "questions_target_check" CHECK (("target" = ANY (ARRAY['cpns'::"text", 'bumn'::"text", 'kedinasan'::"text"]))),
    CONSTRAINT "questions_values_check" CHECK ((("damage_value" >= 0) AND ("heal_value" >= 0) AND ("time_limit_seconds" > 0))),
    CONSTRAINT "questions_weight_check" CHECK ((("weight" >= 1) AND ("weight" <= 3)))
);


ALTER TABLE "public"."questions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."public_questions" WITH ("security_invoker"='true') AS
 SELECT "id",
    "target",
    "category",
    "subcategory",
    "prompt",
    "options",
    "difficulty",
    "weight",
    "effect",
    "damage_value",
    "heal_value",
    "time_limit_seconds",
    "hint",
    "created_at",
    "updated_at"
   FROM "public"."questions"
  WHERE ("is_active" = true);


ALTER VIEW "public"."public_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_items" (
    "id" "text" NOT NULL,
    "type" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text" NOT NULL,
    "rarity" "text" NOT NULL,
    "coin_price" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_pass_exclusive" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "store_items_coin_price_check" CHECK (("coin_price" >= 0)),
    CONSTRAINT "store_items_rarity_check" CHECK (("rarity" = ANY (ARRAY['common'::"text", 'rare'::"text", 'epic'::"text", 'legendary'::"text"]))),
    CONSTRAINT "store_items_type_check" CHECK (("type" = ANY (ARRAY['character_skin'::"text", 'arena'::"text", 'tower'::"text"])))
);


ALTER TABLE "public"."store_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_purchases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "item_id" "text" NOT NULL,
    "idempotency_key" "text" NOT NULL,
    "price_paid" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "store_purchases_price_paid_check" CHECK (("price_paid" >= 0))
);


ALTER TABLE "public"."store_purchases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_hired_pass_mission_progress" (
    "user_id" "uuid" NOT NULL,
    "mission_id" "text" NOT NULL,
    "period_start" "date" NOT NULL,
    "progress_count" integer DEFAULT 0 NOT NULL,
    "completed_at" timestamp with time zone,
    "points_awarded_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_hired_pass_mission_progress_progress_count_check" CHECK (("progress_count" >= 0))
);


ALTER TABLE "public"."user_hired_pass_mission_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_hired_pass_progress" (
    "user_id" "uuid" NOT NULL,
    "season_id" "text" NOT NULL,
    "pass_points" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_hired_pass_progress_pass_points_check" CHECK (("pass_points" >= 0))
);


ALTER TABLE "public"."user_hired_pass_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_hired_pass_reward_claims" (
    "user_id" "uuid" NOT NULL,
    "reward_id" "text" NOT NULL,
    "coins_awarded" integer DEFAULT 0 NOT NULL,
    "item_id" "text",
    "claimed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_hired_pass_reward_claims_coins_awarded_check" CHECK (("coins_awarded" >= 0))
);


ALTER TABLE "public"."user_hired_pass_reward_claims" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_inventory" (
    "user_id" "uuid" NOT NULL,
    "item_id" "text" NOT NULL,
    "source" "text" NOT NULL,
    "source_ref" "text",
    "acquired_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_inventory_source_check" CHECK (("source" = ANY (ARRAY['starter'::"text", 'purchase'::"text", 'hired_pass'::"text", 'admin'::"text"])))
);


ALTER TABLE "public"."user_inventory" OWNER TO "postgres";


ALTER TABLE ONLY "public"."coin_transactions"
    ADD CONSTRAINT "coin_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."coin_transactions"
    ADD CONSTRAINT "coin_transactions_user_id_idempotency_key_key" UNIQUE ("user_id", "idempotency_key");



ALTER TABLE ONLY "public"."hired_pass_activity_events"
    ADD CONSTRAINT "hired_pass_activity_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hired_pass_activity_events"
    ADD CONSTRAINT "hired_pass_activity_events_user_id_mission_id_source_type_s_key" UNIQUE ("user_id", "mission_id", "source_type", "source_id");



ALTER TABLE ONLY "public"."hired_pass_missions"
    ADD CONSTRAINT "hired_pass_missions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hired_pass_rewards"
    ADD CONSTRAINT "hired_pass_rewards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hired_pass_seasons"
    ADD CONSTRAINT "hired_pass_seasons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."interview_company_contexts"
    ADD CONSTRAINT "interview_company_contexts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."interview_company_profiles"
    ADD CONSTRAINT "interview_company_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."interview_sessions"
    ADD CONSTRAINT "interview_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."interview_turns"
    ADD CONSTRAINT "interview_turns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_logs"
    ADD CONSTRAINT "match_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_question_pool"
    ADD CONSTRAINT "match_question_pool_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_results"
    ADD CONSTRAINT "match_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_results"
    ADD CONSTRAINT "match_results_room_id_key" UNIQUE ("room_id");



ALTER TABLE ONLY "public"."practice_answers"
    ADD CONSTRAINT "practice_answers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."practice_session_questions"
    ADD CONSTRAINT "practice_session_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."practice_session_questions"
    ADD CONSTRAINT "practice_session_questions_unique_order" UNIQUE ("session_id", "question_order");



ALTER TABLE ONLY "public"."practice_session_questions"
    ADD CONSTRAINT "practice_session_questions_unique_question" UNIQUE ("session_id", "question_id");



ALTER TABLE ONLY "public"."practice_sessions"
    ADD CONSTRAINT "practice_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."questions"
    ADD CONSTRAINT "questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_items"
    ADD CONSTRAINT "store_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_purchases"
    ADD CONSTRAINT "store_purchases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_purchases"
    ADD CONSTRAINT "store_purchases_user_id_idempotency_key_key" UNIQUE ("user_id", "idempotency_key");



ALTER TABLE ONLY "public"."store_purchases"
    ADD CONSTRAINT "store_purchases_user_id_item_id_key" UNIQUE ("user_id", "item_id");



ALTER TABLE ONLY "public"."user_hired_pass_mission_progress"
    ADD CONSTRAINT "user_hired_pass_mission_progress_pkey" PRIMARY KEY ("user_id", "mission_id", "period_start");



ALTER TABLE ONLY "public"."user_hired_pass_progress"
    ADD CONSTRAINT "user_hired_pass_progress_pkey" PRIMARY KEY ("user_id", "season_id");



ALTER TABLE ONLY "public"."user_hired_pass_reward_claims"
    ADD CONSTRAINT "user_hired_pass_reward_claims_pkey" PRIMARY KEY ("user_id", "reward_id");



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_pkey" PRIMARY KEY ("user_id", "item_id");



CREATE INDEX "coin_transactions_user_idx" ON "public"."coin_transactions" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "hired_pass_missions_season_event_idx" ON "public"."hired_pass_missions" USING "btree" ("season_id", "event_type");



CREATE INDEX "hired_pass_rewards_season_points_idx" ON "public"."hired_pass_rewards" USING "btree" ("season_id", "points_required");



CREATE INDEX "interview_company_contexts_company_priority_idx" ON "public"."interview_company_contexts" USING "btree" ("company_id", "priority");



CREATE INDEX "interview_sessions_user_created_idx" ON "public"."interview_sessions" USING "btree" ("user_id", "created_at" DESC);



CREATE UNIQUE INDEX "interview_turns_parent_question_idx" ON "public"."interview_turns" USING "btree" ("parent_turn_id") WHERE (("role" = 'question'::"text") AND ("parent_turn_id" IS NOT NULL));



CREATE INDEX "interview_turns_session_created_idx" ON "public"."interview_turns" USING "btree" ("session_id", "created_at");



CREATE UNIQUE INDEX "interview_turns_session_idempotency_idx" ON "public"."interview_turns" USING "btree" ("session_id", "idempotency_key") WHERE ("idempotency_key" IS NOT NULL);



CREATE UNIQUE INDEX "interview_turns_session_pending_answer_idx" ON "public"."interview_turns" USING "btree" ("session_id") WHERE (("role" = 'answer'::"text") AND ("processing_status" = 'pending'::"text"));



CREATE INDEX "match_logs_match_timestamp_idx" ON "public"."match_logs" USING "btree" ("match_result_id", "action_timestamp");



CREATE INDEX "match_logs_player_timestamp_idx" ON "public"."match_logs" USING "btree" ("player_id", "action_timestamp" DESC);



CREATE INDEX "match_question_pool_match_order_idx" ON "public"."match_question_pool" USING "btree" ("match_result_id", "card_order");



CREATE INDEX "match_results_player_a_idx" ON "public"."match_results" USING "btree" ("player_a_id", "created_at" DESC);



CREATE INDEX "match_results_player_b_idx" ON "public"."match_results" USING "btree" ("player_b_id", "created_at" DESC);



CREATE INDEX "match_results_winner_idx" ON "public"."match_results" USING "btree" ("winner_user_id", "created_at" DESC);



CREATE INDEX "practice_answers_session_order_idx" ON "public"."practice_answers" USING "btree" ("session_id", "question_order");



CREATE UNIQUE INDEX "practice_answers_session_question_unique_idx" ON "public"."practice_answers" USING "btree" ("session_question_id") WHERE ("session_question_id" IS NOT NULL);



CREATE INDEX "practice_answers_user_created_idx" ON "public"."practice_answers" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "practice_session_questions_session_order_idx" ON "public"."practice_session_questions" USING "btree" ("session_id", "question_order");



CREATE INDEX "practice_sessions_user_started_idx" ON "public"."practice_sessions" USING "btree" ("user_id", "started_at" DESC);



CREATE INDEX "practice_sessions_user_target_category_started_idx" ON "public"."practice_sessions" USING "btree" ("user_id", "target", "category", "subcategory", "started_at" DESC);



CREATE INDEX "practice_sessions_user_target_started_idx" ON "public"."practice_sessions" USING "btree" ("user_id", "target", "started_at" DESC);



CREATE INDEX "profiles_rank_points_idx" ON "public"."profiles" USING "btree" ("rank_points" DESC);



CREATE INDEX "questions_active_category_idx" ON "public"."questions" USING "btree" ("is_active", "category");



CREATE INDEX "questions_active_target_category_idx" ON "public"."questions" USING "btree" ("is_active", "target", "category");



CREATE INDEX "questions_active_target_category_subcategory_idx" ON "public"."questions" USING "btree" ("is_active", "target", "category", "subcategory");



CREATE INDEX "user_inventory_user_idx" ON "public"."user_inventory" USING "btree" ("user_id", "acquired_at" DESC);



CREATE OR REPLACE TRIGGER "interview_company_contexts_updated_at" BEFORE UPDATE ON "public"."interview_company_contexts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "interview_company_profiles_updated_at" BEFORE UPDATE ON "public"."interview_company_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "interview_hired_pass_completion" AFTER UPDATE OF "status" ON "public"."interview_sessions" FOR EACH ROW WHEN ((("old"."status" IS DISTINCT FROM 'completed'::"text") AND ("new"."status" = 'completed'::"text"))) EXECUTE FUNCTION "public"."record_interview_hired_pass_completion"();



CREATE OR REPLACE TRIGGER "interview_sessions_updated_at" BEFORE UPDATE ON "public"."interview_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "practice_hired_pass_completion" AFTER UPDATE OF "finished_at" ON "public"."practice_sessions" FOR EACH ROW WHEN ((("old"."finished_at" IS NULL) AND ("new"."finished_at" IS NOT NULL))) EXECUTE FUNCTION "public"."record_practice_hired_pass_completion"();



CREATE OR REPLACE TRIGGER "set_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_questions_updated_at" BEFORE UPDATE ON "public"."questions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."coin_transactions"
    ADD CONSTRAINT "coin_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hired_pass_activity_events"
    ADD CONSTRAINT "hired_pass_activity_events_mission_id_fkey" FOREIGN KEY ("mission_id") REFERENCES "public"."hired_pass_missions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hired_pass_activity_events"
    ADD CONSTRAINT "hired_pass_activity_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hired_pass_missions"
    ADD CONSTRAINT "hired_pass_missions_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."hired_pass_seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hired_pass_rewards"
    ADD CONSTRAINT "hired_pass_rewards_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."store_items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."hired_pass_rewards"
    ADD CONSTRAINT "hired_pass_rewards_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."hired_pass_seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."interview_company_contexts"
    ADD CONSTRAINT "interview_company_contexts_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."interview_company_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."interview_sessions"
    ADD CONSTRAINT "interview_sessions_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."interview_company_profiles"("id");



ALTER TABLE ONLY "public"."interview_sessions"
    ADD CONSTRAINT "interview_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."interview_turns"
    ADD CONSTRAINT "interview_turns_parent_turn_id_fkey" FOREIGN KEY ("parent_turn_id") REFERENCES "public"."interview_turns"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."interview_turns"
    ADD CONSTRAINT "interview_turns_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."interview_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_logs"
    ADD CONSTRAINT "match_logs_match_result_id_fkey" FOREIGN KEY ("match_result_id") REFERENCES "public"."match_results"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_logs"
    ADD CONSTRAINT "match_logs_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."match_logs"
    ADD CONSTRAINT "match_logs_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."match_question_pool"
    ADD CONSTRAINT "match_question_pool_match_result_id_fkey" FOREIGN KEY ("match_result_id") REFERENCES "public"."match_results"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_question_pool"
    ADD CONSTRAINT "match_question_pool_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."match_results"
    ADD CONSTRAINT "match_results_loser_user_id_fkey" FOREIGN KEY ("loser_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."match_results"
    ADD CONSTRAINT "match_results_player_a_id_fkey" FOREIGN KEY ("player_a_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."match_results"
    ADD CONSTRAINT "match_results_player_b_id_fkey" FOREIGN KEY ("player_b_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."match_results"
    ADD CONSTRAINT "match_results_winner_user_id_fkey" FOREIGN KEY ("winner_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."practice_answers"
    ADD CONSTRAINT "practice_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."practice_answers"
    ADD CONSTRAINT "practice_answers_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."practice_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_answers"
    ADD CONSTRAINT "practice_answers_session_question_id_fkey" FOREIGN KEY ("session_question_id") REFERENCES "public"."practice_session_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_answers"
    ADD CONSTRAINT "practice_answers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_session_questions"
    ADD CONSTRAINT "practice_session_questions_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_session_questions"
    ADD CONSTRAINT "practice_session_questions_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."practice_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_sessions"
    ADD CONSTRAINT "practice_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_equipped_arena_fk" FOREIGN KEY ("equipped_arena_id") REFERENCES "public"."store_items"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_equipped_avatar_fk" FOREIGN KEY ("equipped_avatar_id") REFERENCES "public"."store_items"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_equipped_tower_fk" FOREIGN KEY ("equipped_tower_id") REFERENCES "public"."store_items"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_purchases"
    ADD CONSTRAINT "store_purchases_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."store_items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."store_purchases"
    ADD CONSTRAINT "store_purchases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_hired_pass_mission_progress"
    ADD CONSTRAINT "user_hired_pass_mission_progress_mission_id_fkey" FOREIGN KEY ("mission_id") REFERENCES "public"."hired_pass_missions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_hired_pass_mission_progress"
    ADD CONSTRAINT "user_hired_pass_mission_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_hired_pass_progress"
    ADD CONSTRAINT "user_hired_pass_progress_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "public"."hired_pass_seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_hired_pass_progress"
    ADD CONSTRAINT "user_hired_pass_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_hired_pass_reward_claims"
    ADD CONSTRAINT "user_hired_pass_reward_claims_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."store_items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."user_hired_pass_reward_claims"
    ADD CONSTRAINT "user_hired_pass_reward_claims_reward_id_fkey" FOREIGN KEY ("reward_id") REFERENCES "public"."hired_pass_rewards"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_hired_pass_reward_claims"
    ADD CONSTRAINT "user_hired_pass_reward_claims_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."store_items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Company contexts are readable by authenticated users" ON "public"."interview_company_contexts" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Company profiles are readable by authenticated users" ON "public"."interview_company_profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Hired Pass missions are publicly readable" ON "public"."hired_pass_missions" FOR SELECT TO "authenticated", "anon" USING ("is_active");



CREATE POLICY "Hired Pass rewards are publicly readable" ON "public"."hired_pass_rewards" FOR SELECT TO "authenticated", "anon" USING ("is_active");



CREATE POLICY "Hired Pass seasons are publicly readable" ON "public"."hired_pass_seasons" FOR SELECT TO "authenticated", "anon" USING ("is_active");



CREATE POLICY "Leaderboard profiles are readable by anon users" ON "public"."profiles" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Profiles are readable by authenticated users" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Store items are publicly readable" ON "public"."store_items" FOR SELECT TO "authenticated", "anon" USING ("is_active");



CREATE POLICY "Users can access their own interview sessions" ON "public"."interview_sessions" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can access turns belonging to their active sessions" ON "public"."interview_turns" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."interview_sessions" "s"
  WHERE (("s"."id" = "interview_turns"."session_id") AND ("s"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can manage their own practice answers" ON "public"."practice_answers" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage their own practice sessions" ON "public"."practice_sessions" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own match logs" ON "public"."match_logs" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."match_results" "mr"
  WHERE (("mr"."id" = "match_logs"."match_result_id") AND (("mr"."player_a_id" = "auth"."uid"()) OR ("mr"."player_b_id" = "auth"."uid"()))))));



CREATE POLICY "Users can read own match question pool" ON "public"."match_question_pool" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."match_results" "mr"
  WHERE (("mr"."id" = "match_question_pool"."match_result_id") AND (("mr"."player_a_id" = "auth"."uid"()) OR ("mr"."player_b_id" = "auth"."uid"()))))));



CREATE POLICY "Users can read their own Hired Pass progress" ON "public"."user_hired_pass_progress" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own coin transactions" ON "public"."coin_transactions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own inventory" ON "public"."user_inventory" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own match results" ON "public"."match_results" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "player_a_id") OR ("auth"."uid"() = "player_b_id")));



CREATE POLICY "Users can read their own mission progress" ON "public"."user_hired_pass_mission_progress" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own practice answers" ON "public"."practice_answers" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own practice session questions" ON "public"."practice_session_questions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."practice_sessions" "ps"
  WHERE (("ps"."id" = "practice_session_questions"."session_id") AND ("ps"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can read their own practice sessions" ON "public"."practice_sessions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own purchases" ON "public"."store_purchases" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own reward claims" ON "public"."user_hired_pass_reward_claims" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."coin_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."hired_pass_activity_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."hired_pass_missions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."hired_pass_rewards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."hired_pass_seasons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."interview_company_contexts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."interview_company_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."interview_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."interview_turns" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_question_pool" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_results" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."practice_answers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."practice_session_questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."practice_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_purchases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_hired_pass_mission_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_hired_pass_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_hired_pass_reward_claims" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_inventory" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































REVOKE ALL ON FUNCTION "public"."claim_hired_pass_reward"("p_user_id" "uuid", "p_reward_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_hired_pass_reward"("p_user_id" "uuid", "p_reward_id" "text") TO "service_role";



GRANT ALL ON TABLE "public"."match_results" TO "anon";
GRANT ALL ON TABLE "public"."match_results" TO "authenticated";
GRANT ALL ON TABLE "public"."match_results" TO "service_role";



GRANT ALL ON FUNCTION "public"."finalize_match_result"("p_room_id" "uuid", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_outcome" "text", "p_final_hp_a" integer, "p_final_hp_b" integer, "p_score_a" integer, "p_score_b" integer, "p_reason" "text", "p_is_bot_match" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."finalize_match_result"("p_room_id" "uuid", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_outcome" "text", "p_final_hp_a" integer, "p_final_hp_b" integer, "p_score_a" integer, "p_score_b" integer, "p_reason" "text", "p_is_bot_match" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."finalize_match_result"("p_room_id" "uuid", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_outcome" "text", "p_final_hp_a" integer, "p_final_hp_b" integer, "p_score_a" integer, "p_score_b" integer, "p_reason" "text", "p_is_bot_match" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."finalize_match_result"("p_room_id" "text", "p_mode" "text", "p_target" "text", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_winner_user_id" "uuid", "p_loser_user_id" "uuid", "p_outcome" "text", "p_reason" "text", "p_player_a_hp" integer, "p_player_b_hp" integer, "p_player_a_points" integer, "p_player_b_points" integer, "p_duration_seconds" integer, "p_started_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."finalize_match_result"("p_room_id" "text", "p_mode" "text", "p_target" "text", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_winner_user_id" "uuid", "p_loser_user_id" "uuid", "p_outcome" "text", "p_reason" "text", "p_player_a_hp" integer, "p_player_b_hp" integer, "p_player_a_points" integer, "p_player_b_points" integer, "p_duration_seconds" integer, "p_started_at" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."finalize_match_result"("p_room_id" "text", "p_mode" "text", "p_target" "text", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_winner_user_id" "uuid", "p_loser_user_id" "uuid", "p_outcome" "text", "p_reason" "text", "p_player_a_hp" integer, "p_player_b_hp" integer, "p_player_a_points" integer, "p_player_b_points" integer, "p_duration_seconds" integer, "p_started_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."finalize_match_result"("p_room_id" "text", "p_mode" "text", "p_target" "text", "p_player_a_id" "uuid", "p_player_b_id" "uuid", "p_winner_user_id" "uuid", "p_loser_user_id" "uuid", "p_outcome" "text", "p_reason" "text", "p_player_a_hp" integer, "p_player_b_hp" integer, "p_player_a_points" integer, "p_player_b_points" integer, "p_duration_seconds" integer, "p_started_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_practice_analytics"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_practice_analytics"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_practice_analytics"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."grant_beta_credit"("p_user_id" "uuid", "p_idempotency_key" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."grant_beta_credit"("p_user_id" "uuid", "p_idempotency_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."purchase_store_item"("p_user_id" "uuid", "p_item_id" "text", "p_idempotency_key" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purchase_store_item"("p_user_id" "uuid", "p_item_id" "text", "p_idempotency_key" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."record_hired_pass_activity"("p_user_id" "uuid", "p_event_type" "text", "p_source_id" "text", "p_occurred_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."record_hired_pass_activity"("p_user_id" "uuid", "p_event_type" "text", "p_source_id" "text", "p_occurred_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."record_interview_hired_pass_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."record_interview_hired_pass_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_interview_hired_pass_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."record_practice_hired_pass_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."record_practice_hired_pass_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_practice_hired_pass_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_profile_loadout"("p_user_id" "uuid", "p_avatar_id" "text", "p_tower_id" "text", "p_arena_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_profile_loadout"("p_user_id" "uuid", "p_avatar_id" "text", "p_tower_id" "text", "p_arena_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";


















GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."coin_transactions" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."coin_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."coin_transactions" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."hired_pass_activity_events" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."hired_pass_activity_events" TO "authenticated";
GRANT ALL ON TABLE "public"."hired_pass_activity_events" TO "service_role";



GRANT ALL ON TABLE "public"."hired_pass_missions" TO "anon";
GRANT ALL ON TABLE "public"."hired_pass_missions" TO "authenticated";
GRANT ALL ON TABLE "public"."hired_pass_missions" TO "service_role";



GRANT ALL ON TABLE "public"."hired_pass_rewards" TO "anon";
GRANT ALL ON TABLE "public"."hired_pass_rewards" TO "authenticated";
GRANT ALL ON TABLE "public"."hired_pass_rewards" TO "service_role";



GRANT ALL ON TABLE "public"."hired_pass_seasons" TO "anon";
GRANT ALL ON TABLE "public"."hired_pass_seasons" TO "authenticated";
GRANT ALL ON TABLE "public"."hired_pass_seasons" TO "service_role";



GRANT ALL ON TABLE "public"."interview_company_contexts" TO "anon";
GRANT ALL ON TABLE "public"."interview_company_contexts" TO "authenticated";
GRANT ALL ON TABLE "public"."interview_company_contexts" TO "service_role";



GRANT ALL ON TABLE "public"."interview_company_profiles" TO "anon";
GRANT ALL ON TABLE "public"."interview_company_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."interview_company_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."interview_sessions" TO "anon";
GRANT ALL ON TABLE "public"."interview_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."interview_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."interview_turns" TO "anon";
GRANT ALL ON TABLE "public"."interview_turns" TO "authenticated";
GRANT ALL ON TABLE "public"."interview_turns" TO "service_role";



GRANT ALL ON TABLE "public"."match_logs" TO "anon";
GRANT ALL ON TABLE "public"."match_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."match_logs" TO "service_role";



GRANT ALL ON TABLE "public"."match_question_pool" TO "anon";
GRANT ALL ON TABLE "public"."match_question_pool" TO "authenticated";
GRANT ALL ON TABLE "public"."match_question_pool" TO "service_role";



GRANT ALL ON TABLE "public"."practice_answers" TO "anon";
GRANT ALL ON TABLE "public"."practice_answers" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_answers" TO "service_role";



GRANT ALL ON TABLE "public"."practice_session_questions" TO "anon";
GRANT ALL ON TABLE "public"."practice_session_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_session_questions" TO "service_role";



GRANT ALL ON TABLE "public"."practice_sessions" TO "anon";
GRANT ALL ON TABLE "public"."practice_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_sessions" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."questions" TO "anon";
GRANT ALL ON TABLE "public"."questions" TO "authenticated";
GRANT ALL ON TABLE "public"."questions" TO "service_role";



GRANT ALL ON TABLE "public"."public_questions" TO "anon";
GRANT ALL ON TABLE "public"."public_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."public_questions" TO "service_role";



GRANT ALL ON TABLE "public"."store_items" TO "anon";
GRANT ALL ON TABLE "public"."store_items" TO "authenticated";
GRANT ALL ON TABLE "public"."store_items" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."store_purchases" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."store_purchases" TO "authenticated";
GRANT ALL ON TABLE "public"."store_purchases" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_hired_pass_mission_progress" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_hired_pass_mission_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."user_hired_pass_mission_progress" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_hired_pass_progress" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_hired_pass_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."user_hired_pass_progress" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_hired_pass_reward_claims" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_hired_pass_reward_claims" TO "authenticated";
GRANT ALL ON TABLE "public"."user_hired_pass_reward_claims" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_inventory" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."user_inventory" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";


































\unrestrict GhSyYr7p949Qgg16DmVC4ENAD4yZ9tcm4z6S36kNYOJH7RVOi5XFvm3Y8tKmFeq

RESET ALL;
