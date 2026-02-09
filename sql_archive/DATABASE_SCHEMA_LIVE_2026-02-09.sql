


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'Platform leaderboard caches migrated to VIEWs in migration 1011. No refresh functions needed - VIEWs always show current data.';



CREATE OR REPLACE FUNCTION "public"."add_ai_credits"("p_user_id" "uuid", "p_credits" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO user_premium_status (
    user_id,
    monthly_ai_credits,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    p_credits,
    now(),
    now()
  )
  ON CONFLICT (user_id) 
  DO UPDATE SET
    monthly_ai_credits = user_premium_status.monthly_ai_credits + p_credits,
    updated_at = now();
END;
$$;


ALTER FUNCTION "public"."add_ai_credits"("p_user_id" "uuid", "p_credits" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_ai_pack_credits"("p_user_id" "uuid", "p_pack_type" character varying, "p_credits" integer, "p_price" numeric, "p_platform" character varying) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  -- Add credits to user's account with explicit schema
  INSERT INTO public.user_ai_credits (user_id, pack_credits)
  VALUES (p_user_id, p_credits)
  ON CONFLICT (user_id)
  DO UPDATE SET 
    pack_credits = public.user_ai_credits.pack_credits + p_credits,
    updated_at = NOW();

  -- Record purchase with explicit schema
  INSERT INTO public.user_ai_pack_purchases (user_id, pack_type, credits_purchased, price_paid, platform)
  VALUES (p_user_id, p_pack_type, p_credits, p_price, p_platform);

  -- Return new credit balance
  RETURN json_build_object(
    'success', true,
    'new_balance', (SELECT pack_credits FROM public.user_ai_credits WHERE user_id = p_user_id)
  );
END;
$$;


ALTER FUNCTION "public"."add_ai_pack_credits"("p_user_id" "uuid", "p_pack_type" character varying, "p_credits" integer, "p_price" numeric, "p_platform" character varying) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."add_ai_pack_credits"("p_user_id" "uuid", "p_pack_type" character varying, "p_credits" integer, "p_price" numeric, "p_platform" character varying) IS 'Adds purchased AI credits - search_path set to prevent attacks';



CREATE OR REPLACE FUNCTION "public"."auto_refresh_all_leaderboards"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- StatusXP (table) refresh
  PERFORM public.refresh_leaderboard_cache();

  -- Platform leaderboards are views and stay current automatically
  PERFORM public.refresh_psn_leaderboard_cache();
  PERFORM public.refresh_xbox_leaderboard_cache();
  PERFORM public.refresh_steam_leaderboard_cache();
END;
$$;


ALTER FUNCTION "public"."auto_refresh_all_leaderboards"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_achievement_similarity"("game_id_1" bigint, "game_id_2" bigint) RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  total_achievements_1 INT;
  total_achievements_2 INT;
  matching_achievements INT;
  similarity_score NUMERIC;
BEGIN
  -- Count total achievements for each game
  SELECT COUNT(*) INTO total_achievements_1
  FROM achievements
  WHERE game_title_id = game_id_1;
  
  SELECT COUNT(*) INTO total_achievements_2
  FROM achievements
  WHERE game_title_id = game_id_2;
  
  -- If either game has no achievements, return 0
  IF total_achievements_1 = 0 OR total_achievements_2 = 0 THEN
    RETURN 0;
  END IF;
  
  -- Count matching achievement names (case-insensitive, trimmed)
  SELECT COUNT(DISTINCT a1.id) INTO matching_achievements
  FROM achievements a1
  INNER JOIN achievements a2 
    ON LOWER(TRIM(a1.name)) = LOWER(TRIM(a2.name))
  WHERE a1.game_title_id = game_id_1
    AND a2.game_title_id = game_id_2;
  
  -- Calculate similarity as percentage of matching achievements
  -- Use the smaller count as the denominator to handle cases where one platform has DLC
  similarity_score := (matching_achievements::NUMERIC / LEAST(total_achievements_1, total_achievements_2)) * 100;
  
  RETURN similarity_score;
END;
$$;


ALTER FUNCTION "public"."calculate_achievement_similarity"("game_id_1" bigint, "game_id_2" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_achievement_statusxp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Only calculate if we include in score (platinums excluded)
  IF NEW.include_in_score = false THEN
    NEW.base_status_xp := 0;
    RETURN NEW;
  END IF;

  -- Default for unknown rarity (treat as common)
  IF NEW.rarity_global IS NULL THEN
    NEW.base_status_xp := 0.5;
    RETURN NEW;
  END IF;

  -- Exponential curve: base = 0.5 + (12 - 0.5) * (1 - rarity_global/100)^3
  NEW.base_status_xp := GREATEST(0.5, 
    LEAST(12.0, 
      0.5 + (12.0 - 0.5) * POWER(
        GREATEST(0, LEAST(1, 1 - (NEW.rarity_global / 100.0))),
        3
      )
    )
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_achievement_statusxp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_statusxp_simple"("p_user_id" "uuid") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "statusxp" bigint)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    SUM(a.base_status_xp)::BIGINT as statusxp
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND a.include_in_score = true
  GROUP BY ua.platform_id, ua.platform_game_id;
END;
$$;


ALTER FUNCTION "public"."calculate_statusxp_simple"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_statusxp_with_stacks"("p_user_id" "uuid") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "game_name" "text", "achievements_earned" integer, "statusxp_raw" integer, "stack_index" integer, "stack_multiplier" numeric, "statusxp_effective" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH game_raw_xp AS (
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      g.name as game_name,
      COUNT(*)::integer as achievements_earned,
      -- Apply rarity multiplier per achievement
      SUM((a.base_status_xp) * COALESCE(a.rarity_multiplier, 1.0))::integer as statusxp_raw
    FROM public.user_achievements ua
    JOIN public.achievements a ON 
      a.platform_id = ua.platform_id
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    JOIN public.games g ON 
      g.platform_id = ua.platform_id
      AND g.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND a.include_in_score = true
    GROUP BY ua.platform_id, ua.platform_game_id, g.name
  ),
  game_stacks AS (
    -- Keep stack_index for reference only; no longer applies penalties
    SELECT 
      grx.*,
      ROW_NUMBER() OVER (
        PARTITION BY grx.platform_id::text || '_' || grx.platform_game_id
        ORDER BY grx.platform_id, grx.platform_game_id
      )::integer as stack_index
    FROM game_raw_xp grx
  )
  SELECT 
    gs.platform_id,
    gs.platform_game_id,
    gs.game_name,
    gs.achievements_earned,
    gs.statusxp_raw,
    gs.stack_index,
    1.0::numeric as stack_multiplier,
    gs.statusxp_raw as statusxp_effective
  FROM game_stacks gs
  ORDER BY statusxp_effective DESC;
END;
$$;


ALTER FUNCTION "public"."calculate_statusxp_with_stacks"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_user_achievement_statusxp"() RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public, pg_temp'
    AS $$
BEGIN
  UPDATE public.user_achievements ua
  SET statusxp_points = a.base_status_xp
  FROM public.achievements a
  WHERE ua.achievement_id = a.id;
END;
$$;


ALTER FUNCTION "public"."calculate_user_achievement_statusxp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_user_game_statusxp"() RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public, pg_temp'
    AS $$
BEGIN
  WITH game_statusxp AS (
    SELECT 
      ug.id as user_game_id,
      COALESCE(SUM(a.base_status_xp), 0) as raw_xp,
      COUNT(*) FILTER (WHERE a.is_dlc = false AND ua.id IS NOT NULL) as base_unlocked,
      COUNT(*) FILTER (WHERE a.is_dlc = false) as base_total
    FROM public.user_games ug
    CROSS JOIN LATERAL (
      SELECT code as platform_code FROM public.platforms WHERE id = ug.platform_id
    ) p
    LEFT JOIN public.achievements a ON a.game_title_id = ug.game_title_id 
      AND (
        (a.platform = 'psn' AND p.platform_code IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
        (a.platform = 'xbox' AND p.platform_code LIKE '%XBOX%') OR
        (a.platform = 'steam' AND p.platform_code = 'Steam')
      )
    LEFT JOIN public.user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
    GROUP BY ug.id
  )
  UPDATE public.user_games ug
  SET 
    statusxp_raw = gs.raw_xp::integer,
    base_completed = (gs.base_total > 0 AND gs.base_unlocked = gs.base_total),
    statusxp_effective = (gs.raw_xp * stack_multiplier)::integer
  FROM game_statusxp gs
  WHERE ug.id = gs.user_game_id;
END;
$$;


ALTER FUNCTION "public"."calculate_user_game_statusxp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_use_ai"("p_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_pack_credits INTEGER;
  v_daily_free_used INTEGER;
  v_daily_free_limit INTEGER := 3;
BEGIN
  -- Check if user is premium
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- If premium, unlimited AI usage
  IF v_is_premium THEN
    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'premium',
      'remaining', -1,
      'pack_credits', 0,
      'daily_free_remaining', 0
    );
  END IF;

  -- Check pack credits
  SELECT COALESCE(pack_credits, 0) INTO v_pack_credits
  FROM user_ai_credits
  WHERE user_id = p_user_id;

  -- If user has pack credits, use those
  IF v_pack_credits > 0 THEN
    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'pack',
      'remaining', v_pack_credits,
      'pack_credits', v_pack_credits,
      'daily_free_remaining', 0
    );
  END IF;

  -- Check daily free usage
  SELECT COALESCE(COUNT(*), 0) INTO v_daily_free_used
  FROM user_ai_daily_usage
  WHERE user_id = p_user_id
    AND used_at::DATE = CURRENT_DATE
    AND source = 'daily_free';

  -- Check if daily free limit reached
  IF v_daily_free_used >= v_daily_free_limit THEN
    RETURN json_build_object(
      'can_use', FALSE,
      'source', 'daily_free',
      'remaining', 0,
      'pack_credits', 0,
      'daily_free_remaining', 0
    );
  END IF;

  -- Can use daily free
  RETURN json_build_object(
    'can_use', TRUE,
    'source', 'daily_free',
    'remaining', v_daily_free_limit - v_daily_free_used,
    'pack_credits', 0,
    'daily_free_remaining', v_daily_free_limit - v_daily_free_used
  );
END;
$$;


ALTER FUNCTION "public"."can_use_ai"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."can_use_ai"("p_user_id" "uuid") IS 'Check if user can use AI features - with secure search_path';



CREATE OR REPLACE FUNCTION "public"."can_user_sync"("p_user_id" "uuid", "p_platform" "text") RETURNS json
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_syncs_today INTEGER;
  v_last_sync_at TIMESTAMPTZ;
  v_cooldown_minutes INTEGER;
  v_daily_limit INTEGER;
  v_wait_seconds INTEGER;
BEGIN
  -- Get premium status
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- Get sync stats for today
  SELECT 
    COALESCE(COUNT(*) FILTER (WHERE synced_at::DATE = CURRENT_DATE), 0),
    MAX(synced_at)
  INTO v_syncs_today, v_last_sync_at
  FROM user_sync_history
  WHERE user_id = p_user_id 
    AND platform = p_platform
    AND success = TRUE;

  -- Set limits based on platform and premium status
  IF p_platform = 'psn' THEN
    IF v_is_premium THEN
      v_cooldown_minutes := 30;
      v_daily_limit := 12;
    ELSE
      v_cooldown_minutes := 120;
      v_daily_limit := 3;
    END IF;
  ELSE
    IF v_is_premium THEN
      v_cooldown_minutes := 15;
      v_daily_limit := 999;
    ELSE
      v_cooldown_minutes := 60;
      v_daily_limit := 999;
    END IF;
  END IF;

  -- Check daily limit
  IF v_syncs_today >= v_daily_limit THEN
    RETURN json_build_object(
      'can_sync', FALSE,
      'reason', format('Daily limit reached (%s/%s)', v_syncs_today, v_daily_limit),
      'wait_seconds', 0
    );
  END IF;

  -- Check cooldown
  IF v_last_sync_at IS NOT NULL THEN
    v_wait_seconds := GREATEST(0, 
      EXTRACT(EPOCH FROM (v_last_sync_at + (v_cooldown_minutes || ' minutes')::INTERVAL - NOW()))::INTEGER
    );
    
    IF v_wait_seconds > 0 THEN
      RETURN json_build_object(
        'can_sync', FALSE,
        'reason', format('Cooldown active (%s minutes)', v_cooldown_minutes),
        'wait_seconds', v_wait_seconds
      );
    END IF;
  END IF;

  -- Can sync
  RETURN json_build_object(
    'can_sync', TRUE,
    'syncs_today', v_syncs_today,
    'daily_limit', v_daily_limit
  );
END;
$$;


ALTER FUNCTION "public"."can_user_sync"("p_user_id" "uuid", "p_platform" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."can_user_sync"("p_user_id" "uuid", "p_platform" "text") IS 'Check if user can perform sync - with secure search_path';



CREATE OR REPLACE FUNCTION "public"."can_user_sync_psn"("user_id" "uuid") RETURNS TABLE("can_sync" boolean, "reason" "text", "next_sync_available_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public, pg_temp'
    AS $$
declare
  v_subscription_tier text;
  v_last_sync_at timestamptz;
  v_sync_cooldown interval;
  v_next_available timestamptz;
begin
  -- Get user's subscription tier and last sync time
  select 
    subscription_tier,
    last_psn_sync_at
  into 
    v_subscription_tier,
    v_last_sync_at
  from profiles
  where id = user_id;

  -- If never synced, always allow (first-time sync is free)
  if v_last_sync_at is null then
    return query select true, 'First sync - no cooldown'::text, null::timestamptz;
    return;
  end if;

  -- Determine cooldown based on subscription tier
  v_sync_cooldown := case 
    when v_subscription_tier = 'premium' then interval '8 hours'
    else interval '24 hours'
  end;

  -- Calculate when next sync is available
  v_next_available := v_last_sync_at + v_sync_cooldown;

  -- Check if cooldown has passed
  if now() >= v_next_available then
    return query select true, 'Cooldown expired'::text, null::timestamptz;
  else
    return query select 
      false, 
      format('Sync cooldown active. %s users can sync every %s', 
        initcap(v_subscription_tier), 
        case 
          when v_subscription_tier = 'premium' then '8 hours'
          else '24 hours'
        end
      )::text,
      v_next_available;
  end if;
end;
$$;


ALTER FUNCTION "public"."can_user_sync_psn"("user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."can_user_sync_psn"("user_id" "uuid") IS 'Check if user can start a new PSN sync based on subscription tier rate limits';



CREATE OR REPLACE FUNCTION "public"."check_big_comeback"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM (
      SELECT 
        game_title_id,
        MIN(completion_percent) as min_completion,
        MAX(completion_percent) as max_completion
      FROM public.completion_history
      WHERE user_id = p_user_id
      GROUP BY game_title_id
    ) game_progress
    WHERE min_completion < 10 AND max_completion >= 50
  );
END;
$$;


ALTER FUNCTION "public"."check_big_comeback"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_closer"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM (
      SELECT 
        game_title_id,
        MIN(completion_percent) as min_completion,
        MAX(completion_percent) as max_completion
      FROM public.completion_history
      WHERE user_id = p_user_id
      GROUP BY game_title_id
    ) game_progress
    WHERE min_completion < 50 AND max_completion >= 100
  );
END;
$$;


ALTER FUNCTION "public"."check_closer"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_game_hopper"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  max_games_in_day INTEGER;
BEGIN
  SELECT MAX(game_count) INTO max_games_in_day
  FROM (
    SELECT 
      DATE(ut.earned_at) as earn_date,
      COUNT(DISTINCT ug.game_title_id) as game_count
    FROM public.user_trophies ut
    JOIN public.user_games ug ON ug.user_id = ut.user_id
    JOIN public.trophies t ON t.id = ut.trophy_id AND t.game_title_id = ug.game_title_id
    WHERE ut.user_id = p_user_id
      AND ut.earned_at IS NOT NULL
    GROUP BY DATE(ut.earned_at)
  ) daily_games;
  
  RETURN COALESCE(max_games_in_day, 0) >= 5;
END;
$$;


ALTER FUNCTION "public"."check_game_hopper"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_genre_diversity"("p_user_id" "uuid", "p_required_count" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  unique_genres INTEGER;
BEGIN
  SELECT COUNT(DISTINCT unnest(gt.genres)) INTO unique_genres
  FROM public.user_games ug
  JOIN public.game_titles gt ON gt.id = ug.game_title_id
  WHERE ug.user_id = p_user_id
    AND ug.completion_percent >= 100
    AND gt.genres IS NOT NULL
    AND array_length(gt.genres, 1) > 0;
  
  RETURN COALESCE(unique_genres, 0) >= p_required_count;
END;
$$;


ALTER FUNCTION "public"."check_genre_diversity"("p_user_id" "uuid", "p_required_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_glow_up"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  earliest_avg NUMERIC;
  latest_avg NUMERIC;
BEGIN
  SELECT AVG(completion_percent) INTO earliest_avg
  FROM (
    SELECT DISTINCT ON (game_title_id) 
      game_title_id,
      completion_percent
    FROM public.completion_history
    WHERE user_id = p_user_id
    ORDER BY game_title_id, recorded_at ASC
  ) earliest;
  
  SELECT AVG(completion_percent) INTO latest_avg
  FROM (
    SELECT DISTINCT ON (game_title_id)
      game_title_id,
      completion_percent
    FROM public.completion_history
    WHERE user_id = p_user_id
    ORDER BY game_title_id, recorded_at DESC
  ) latest;
  
  RETURN COALESCE(latest_avg, 0) - COALESCE(earliest_avg, 0) >= 5;
END;
$$;


ALTER FUNCTION "public"."check_glow_up"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_power_session"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  max_trophies_in_24h INTEGER;
BEGIN
  SELECT MAX(trophy_count) INTO max_trophies_in_24h
  FROM (
    SELECT 
      ut1.earned_at,
      COUNT(*) as trophy_count
    FROM public.user_trophies ut1
    JOIN public.user_trophies ut2 ON ut2.user_id = ut1.user_id
      AND ut2.earned_at >= ut1.earned_at
      AND ut2.earned_at < ut1.earned_at + INTERVAL '24 hours'
    WHERE ut1.user_id = p_user_id
      AND ut1.earned_at IS NOT NULL
    GROUP BY ut1.earned_at
  ) rolling_counts;
  
  RETURN COALESCE(max_trophies_in_24h, 0) >= 100;
END;
$$;


ALTER FUNCTION "public"."check_power_session"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_spike_week"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  max_completions_in_week INTEGER;
BEGIN
  -- Use explicit schema reference
  SELECT COUNT(*) INTO max_completions_in_week
  FROM public.user_games
  WHERE user_id = p_user_id
    AND has_platinum = true;
  
  RETURN COALESCE(max_completions_in_week, 0) >= 3;
END;
$$;


ALTER FUNCTION "public"."check_spike_week"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_old_activity_feed"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM activity_feed
  WHERE expires_at < CURRENT_DATE;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RAISE NOTICE 'Activity feed cleanup: deleted % expired stories', deleted_count;
  
  RETURN deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_old_activity_feed"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."cleanup_old_activity_feed"() IS 'Deletes activity feed stories older than 7 days (call daily)';



CREATE OR REPLACE FUNCTION "public"."cleanup_old_snapshots"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM user_stat_snapshots
  WHERE synced_at < NOW() - INTERVAL '30 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RAISE NOTICE 'Snapshot cleanup: deleted % old snapshots', deleted_count;
  
  RETURN deleted_count;
END;
$$;


ALTER FUNCTION "public"."cleanup_old_snapshots"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."cleanup_old_snapshots"() IS 'Deletes snapshots older than 30 days (call daily)';



CREATE OR REPLACE FUNCTION "public"."consume_ai_credit"("p_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_pack_credits INTEGER;
  v_uses_today INTEGER;
  v_daily_free_limit INTEGER := 3;
BEGIN
  -- Check premium status
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- Premium users: unlimited, just log usage
  IF v_is_premium THEN
    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today, source)
    VALUES (p_user_id, CURRENT_DATE, 1, 'premium')
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET 
      uses_today = user_ai_daily_usage.uses_today + 1,
      source = 'premium';
    
    RETURN json_build_object('success', TRUE, 'source', 'premium');
  END IF;

  -- Check pack credits
  SELECT COALESCE(pack_credits, 0) INTO v_pack_credits
  FROM user_ai_credits
  WHERE user_id = p_user_id;

  -- Use pack credit if available
  IF v_pack_credits > 0 THEN
    UPDATE user_ai_credits
    SET pack_credits = pack_credits - 1,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today, source)
    VALUES (p_user_id, CURRENT_DATE, 1, 'pack')
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET 
      uses_today = user_ai_daily_usage.uses_today + 1,
      source = 'pack';

    RETURN json_build_object('success', TRUE, 'source', 'pack');
  END IF;

  -- Check daily free usage
  SELECT COALESCE(uses_today, 0) INTO v_uses_today
  FROM user_ai_daily_usage
  WHERE user_id = p_user_id
    AND usage_date = CURRENT_DATE;

  v_uses_today := COALESCE(v_uses_today, 0);

  -- Use daily free if available
  IF v_uses_today < v_daily_free_limit THEN
    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today, source)
    VALUES (p_user_id, CURRENT_DATE, 1, 'daily_free')
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET uses_today = user_ai_daily_usage.uses_today + 1;

    RETURN json_build_object('success', TRUE, 'source', 'daily_free');
  END IF;

  -- No credits available
  RETURN json_build_object('success', FALSE, 'error', 'No AI credits available');
END;
$$;


ALTER FUNCTION "public"."consume_ai_credit"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."consume_ai_credit"("p_user_id" "uuid") IS 'Consume one AI credit - with secure search_path';



CREATE OR REPLACE FUNCTION "public"."get_activity_feed_grouped"("p_user_id" "uuid", "p_limit" integer DEFAULT 50) RETURNS TABLE("event_date" "date", "story_count" bigint, "stories" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    af.event_date,
    COUNT(*)::BIGINT as story_count,
    jsonb_agg(
      jsonb_build_object(
        'id', af.id,
        'user_id', af.user_id,
        'story_text', af.story_text,
        'event_type', af.event_type,
        'username', af.username,
        'avatar_url', af.avatar_url,
        'game_title', af.game_title,
        'created_at', af.created_at,
        'old_value', af.old_value,
        'new_value', af.new_value,
        'change_amount', af.change_amount
      ) ORDER BY af.created_at DESC
    ) as stories
  FROM activity_feed af
  WHERE af.is_visible = true
    AND af.expires_at >= CURRENT_DATE -- Only non-expired
  GROUP BY af.event_date
  ORDER BY af.event_date DESC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_activity_feed_grouped"("p_user_id" "uuid", "p_limit" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_activity_feed_grouped"("p_user_id" "uuid", "p_limit" integer) IS 'Returns activity feed grouped by date with story JSON aggregation';



CREATE OR REPLACE FUNCTION "public"."get_games_with_platforms"("search_query" "text" DEFAULT NULL::"text", "platform_filter" "text" DEFAULT NULL::"text", "result_limit" integer DEFAULT 100, "result_offset" integer DEFAULT 0) RETURNS TABLE("id" bigint, "name" "text", "cover_url" "text", "platforms" "text"[])
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    gt.id,
    gt.name,
    gt.cover_url,
    ARRAY_AGG(DISTINCT a.platform) FILTER (WHERE a.platform IS NOT NULL) as platforms
  FROM game_titles gt
  LEFT JOIN achievements a ON a.game_title_id = gt.id
  WHERE 
    (search_query IS NULL OR gt.name ILIKE '%' || search_query || '%')
    AND (
      platform_filter IS NULL 
      OR EXISTS (
        SELECT 1 FROM achievements a2 
        WHERE a2.game_title_id = gt.id 
        AND a2.platform = platform_filter
      )
    )
  GROUP BY gt.id, gt.name, gt.cover_url
  HAVING COUNT(a.id) > 0  -- Only games with achievements
  ORDER BY gt.name
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;


ALTER FUNCTION "public"."get_games_with_platforms"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_grouped_games"("search_query" "text" DEFAULT NULL::"text", "platform_filter" "text" DEFAULT NULL::"text", "result_limit" integer DEFAULT 100, "result_offset" integer DEFAULT 0, "sort_by" "text" DEFAULT 'name_asc'::"text") RETURNS TABLE("group_id" "text", "name" "text", "cover_url" "text", "platforms" "text"[], "game_title_ids" bigint[], "total_achievements" integer, "primary_game_id" bigint)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  processed_ids BIGINT[] := ARRAY[]::BIGINT[];
  current_game RECORD;
  similar_game RECORD;
  group_games BIGINT[];
  group_platforms TEXT[];
BEGIN
  -- Create temporary table to store groups
  CREATE TEMP TABLE IF NOT EXISTS temp_game_groups (
    group_id TEXT,
    name TEXT,
    cover_url TEXT,
    platforms TEXT[],
    game_title_ids BIGINT[],
    total_achievements INT,
    primary_game_id BIGINT
  ) ON COMMIT DROP;
  
  -- Iterate through all game_titles
  FOR current_game IN 
    SELECT DISTINCT gt.id, gt.name, gt.cover_url, gt.psn_npwr_id, gt.xbox_title_id, gt.steam_app_id,
           (SELECT COUNT(*) FROM achievements WHERE game_title_id = gt.id) as ach_count
    FROM game_titles gt
    WHERE 
      (search_query IS NULL OR gt.name ILIKE '%' || search_query || '%')
      AND gt.id NOT IN (SELECT UNNEST(processed_ids))
      AND EXISTS (SELECT 1 FROM achievements WHERE game_title_id = gt.id)
    ORDER BY gt.name, gt.id
  LOOP
    -- Skip if already processed
    IF current_game.id = ANY(processed_ids) THEN
      CONTINUE;
    END IF;
    
    -- Start new group with current game
    group_games := ARRAY[current_game.id];
    group_platforms := ARRAY[]::TEXT[];
    
    -- Determine platform for current game
    IF current_game.psn_npwr_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'psn');
    END IF;
    IF current_game.xbox_title_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'xbox');
    END IF;
    IF current_game.steam_app_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'steam');
    END IF;
    
    -- Find similar games (>90% achievement match)
    FOR similar_game IN
      SELECT gt2.id, gt2.psn_npwr_id, gt2.xbox_title_id, gt2.steam_app_id
      FROM game_titles gt2
      WHERE gt2.id != current_game.id
        AND gt2.id NOT IN (SELECT UNNEST(processed_ids))
        AND BTRIM(gt2.name, E' \n\r\t') ILIKE BTRIM(current_game.name, E' \n\r\t') -- Pre-filter by similar name (trim all whitespace)
        AND calculate_achievement_similarity(current_game.id, gt2.id) >= 90
    LOOP
      -- Add to group
      group_games := array_append(group_games, similar_game.id);
      
      -- Add platform
      IF similar_game.psn_npwr_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'psn');
      END IF;
      IF similar_game.xbox_title_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'xbox');
      END IF;
      IF similar_game.steam_app_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'steam');
      END IF;
    END LOOP;
    
    -- Mark all games in group as processed
    processed_ids := processed_ids || group_games;
    
    -- Apply platform filter if specified
    IF platform_filter IS NULL OR platform_filter = ANY(group_platforms) THEN
      INSERT INTO temp_game_groups VALUES (
        'group_' || current_game.id::TEXT,
        current_game.name,
        current_game.cover_url,
        array_remove(ARRAY(SELECT DISTINCT unnest(group_platforms)), NULL),
        group_games,
        current_game.ach_count,
        current_game.id
      );
    END IF;
  END LOOP;
  
  -- Return sorted and paginated results
  RETURN QUERY
  SELECT tgg.*
  FROM temp_game_groups tgg
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN tgg.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN tgg.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;


ALTER FUNCTION "public"."get_grouped_games"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_grouped_games_fast"("search_query" "text" DEFAULT NULL::"text", "platform_filter" "text" DEFAULT NULL::"text", "result_limit" integer DEFAULT 100, "result_offset" integer DEFAULT 0, "sort_by" "text" DEFAULT 'name_asc'::"text") RETURNS TABLE("group_id" "text", "name" "text", "cover_url" "text", "platforms" "text"[], "platform_names" "text"[], "platform_ids" bigint[], "platform_game_ids" "text"[], "total_achievements" integer, "primary_platform_id" bigint, "primary_game_id_str" "text", "primary_game_id" "text", "proxied_cover_url" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  filter_platform_id INT;
BEGIN
  -- Map platform filter to platform_id (CORRECTED MAPPINGS)
  CASE LOWER(platform_filter)
    WHEN 'psn' THEN filter_platform_id := 1;      -- PS5
    WHEN 'ps5' THEN filter_platform_id := 1;      -- PS5
    WHEN 'ps4' THEN filter_platform_id := 2;      -- PS4 (was 4 - WRONG!)
    WHEN 'ps3' THEN filter_platform_id := 5;      -- PS3 (was 2 - WRONG!)
    WHEN 'psvita' THEN filter_platform_id := 9;   -- PSVita
    WHEN 'steam' THEN filter_platform_id := 4;    -- Steam (was 5 - WRONG!)
    WHEN 'xbox' THEN filter_platform_id := 11;    -- XboxOne
    WHEN 'xbox360' THEN filter_platform_id := 10; -- Xbox360
    WHEN 'xboxone' THEN filter_platform_id := 11; -- XboxOne
    WHEN 'xboxseriesx' THEN filter_platform_id := 12; -- XboxSeriesX
    ELSE filter_platform_id := NULL;
  END CASE;

  RETURN QUERY
  SELECT 
    ggc.normalized_name as group_id,
    ggc.name,
    ggc.cover_url,
    ggc.platforms,
    ggc.platform_names,
    ggc.platform_ids,
    ggc.platform_game_ids,
    ggc.total_achievements,
    ggc.primary_platform_id,
    ggc.primary_game_id as primary_game_id_str,
    ggc.primary_game_id as primary_game_id,
    ggc.cover_url as proxied_cover_url
  FROM grouped_games_cache ggc
  WHERE 
    (search_query IS NULL OR ggc.name ILIKE '%' || search_query || '%')
    AND (filter_platform_id IS NULL OR filter_platform_id = ANY(ggc.platform_ids))
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN ggc.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN ggc.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;


ALTER FUNCTION "public"."get_grouped_games_fast"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_grouped_games_fast"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") IS 'Fixed platform ID mappings: PS4=2 (was 4), PS3=5 (was 2), Steam=4 (was 5). Jan 31, 2026.';



CREATE OR REPLACE FUNCTION "public"."get_leaderboard_with_movement"("limit_count" integer DEFAULT 100, "offset_count" integer DEFAULT 0) RETURNS TABLE("user_id" "uuid", "display_name" "text", "avatar_url" "text", "total_statusxp" bigint, "potential_statusxp" bigint, "total_game_entries" integer, "current_rank" bigint, "previous_rank" integer, "rank_change" integer, "is_new" boolean, "preferred_display_platform" "text", "psn_online_id" "text", "psn_avatar_url" "text", "xbox_gamertag" "text", "xbox_avatar_url" "text", "steam_display_name" "text", "steam_avatar_url" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  latest_snapshot_time timestamp with time zone;
BEGIN
  SELECT MAX(snapshot_at) INTO latest_snapshot_time
  FROM public.leaderboard_history
  WHERE snapshot_at < now() - INTERVAL '1 hour';

  RETURN QUERY
  WITH current_ranks AS (
    SELECT 
      lc.user_id,
      ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC) as rank,
      lc.total_statusxp,
      lc.potential_statusxp,
      lc.total_game_entries
    FROM public.leaderboard_cache lc
    JOIN public.profiles p ON p.id = lc.user_id
    WHERE p.show_on_leaderboard = true
      AND lc.total_statusxp > 0
  ),
  previous_ranks AS (
    SELECT DISTINCT ON (lh.user_id)
      lh.user_id,
      lh.rank as prev_rank
    FROM public.leaderboard_history lh
    WHERE lh.snapshot_at = latest_snapshot_time
    ORDER BY lh.user_id
  )
  SELECT 
    cr.user_id,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_online_id
        WHEN 'xbox' THEN p.xbox_gamertag
        WHEN 'steam' THEN p.steam_display_name
      END,
      p.psn_online_id,
      p.xbox_gamertag, 
      p.steam_display_name,
      p.username,
      'Player'::text
    ) as display_name,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_avatar_url
        WHEN 'xbox' THEN p.xbox_avatar_url
        WHEN 'steam' THEN p.steam_avatar_url
        ELSE p.avatar_url
      END,
      p.avatar_url
    ) as avatar_url,
    cr.total_statusxp,
    cr.potential_statusxp,
    cr.total_game_entries,
    cr.rank::bigint as current_rank,
    pr.prev_rank as previous_rank,
    CASE 
      WHEN pr.prev_rank IS NULL THEN 0
      ELSE (pr.prev_rank - cr.rank::integer)
    END as rank_change,
    (pr.prev_rank IS NULL) as is_new,
    p.preferred_display_platform,
    p.psn_online_id,
    p.psn_avatar_url,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    p.steam_display_name,
    p.steam_avatar_url
  FROM current_ranks cr
  JOIN public.profiles p ON p.id = cr.user_id
  LEFT JOIN previous_ranks pr ON pr.user_id = cr.user_id
  ORDER BY cr.rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;


ALTER FUNCTION "public"."get_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_most_time_sunk_game"("p_user_id" "uuid") RETURNS TABLE("game_title_id" bigint, "achievement_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public, pg_temp'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.game_title_id,
    COUNT(*) AS achievement_count
  FROM public.user_achievements ua
  INNER JOIN public.achievements a ON ua.achievement_id = a.id
  WHERE ua.user_id = p_user_id
  GROUP BY a.game_title_id
  ORDER BY achievement_count DESC
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_most_time_sunk_game"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_most_time_sunk_game_v2"("p_user_id" "uuid") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "platform_achievement_id" "text", "earned_at" timestamp with time zone, "rarity_global" numeric, "achievement_name" "text", "achievement_icon_url" "text", "game_name" "text", "game_cover_url" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH game_completion AS (
    SELECT 
      gt.platform_id,
      gt.platform_game_id,
      gt.name as game_name,
      gt.proxied_cover_url,
      gt.cover_url,
      COUNT(ua.platform_achievement_id) as earned_count,
      (SELECT COUNT(*) FROM achievements a2 
       WHERE a2.platform_id = gt.platform_id 
       AND a2.platform_game_id = gt.platform_game_id) as total_count,
      MAX(ua.earned_at) as latest_earned
    FROM game_titles gt
    JOIN user_achievements ua ON 
      gt.platform_id = ua.platform_id 
      AND gt.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND ua.earned_at IS NOT NULL
    GROUP BY gt.platform_id, gt.platform_game_id, gt.name, gt.proxied_cover_url, gt.cover_url
  ),
  best_game AS (
    SELECT * FROM game_completion
    ORDER BY earned_count DESC, total_count DESC
    LIMIT 1
  )
  SELECT 
    bg.platform_id,
    bg.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    bg.game_name,
    COALESCE(bg.proxied_cover_url, bg.cover_url) as game_cover_url
  FROM best_game bg
  JOIN user_achievements ua ON 
    bg.platform_id = ua.platform_id 
    AND bg.platform_game_id = ua.platform_game_id
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
  ORDER BY ua.earned_at DESC
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_most_time_sunk_game_v2"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_platform_achievement_counts"("p_user_id" "uuid") RETURNS TABLE("platform_id" bigint, "platform_code" "text", "platform_name" "text", "earned_rows" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id as platform_id,
    p.code as platform_code,
    p.name as platform_name,
    count(*)::int as earned_rows
  FROM user_achievements ua
  JOIN platforms p ON p.id = ua.platform_id
  WHERE ua.user_id = p_user_id
  GROUP BY p.id, p.code, p.name
  ORDER BY p.id;
END;
$$;


ALTER FUNCTION "public"."get_platform_achievement_counts"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_platform_achievement_counts"("p_user_id" "uuid") IS 'Returns achievement counts grouped by platform for a user. Joins platforms table to return platform_code and platform_name directly instead of requiring frontend mapping.';



CREATE OR REPLACE FUNCTION "public"."get_platinum_leaderboard"("limit_count" integer DEFAULT 100) RETURNS TABLE("user_id" "uuid", "display_name" "text", "avatar_url" "text", "score" bigint, "games_count" bigint)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.psn_online_id,
    p.psn_avatar_url,
    COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) as platinum_count,
    COUNT(DISTINCT ua.achievement_id) as total_games
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'psn'
  WHERE p.show_on_leaderboard = true
    AND p.psn_account_id IS NOT NULL
  GROUP BY p.id, p.psn_online_id, p.psn_avatar_url
  HAVING COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) > 0
  ORDER BY platinum_count DESC, total_games DESC
  LIMIT limit_count;
END;
$$;


ALTER FUNCTION "public"."get_platinum_leaderboard"("limit_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_psn_leaderboard_with_movement"("limit_count" integer DEFAULT 100, "offset_count" integer DEFAULT 0) RETURNS TABLE("user_id" "uuid", "display_name" "text", "avatar_url" "text", "platinum_count" bigint, "gold_count" bigint, "silver_count" bigint, "bronze_count" bigint, "total_trophies" bigint, "total_games" bigint, "possible_platinum" bigint, "possible_gold" bigint, "possible_silver" bigint, "possible_bronze" bigint, "previous_rank" integer, "rank_change" integer, "is_new" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  WITH current_leaderboard AS (
    SELECT 
      lc.user_id,
      lc.display_name,
      lc.avatar_url,
      lc.platinum_count,
      lc.gold_count,
      lc.silver_count,
      lc.bronze_count,
      lc.total_trophies,
      lc.total_games,
      lc.possible_platinum,
      lc.possible_gold,
      lc.possible_silver,
      lc.possible_bronze,
      ROW_NUMBER() OVER (ORDER BY lc.platinum_count DESC, lc.gold_count DESC, lc.silver_count DESC) as current_rank
    FROM psn_leaderboard_cache lc
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM psn_leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.platinum_count,
    cl.gold_count,
    cl.silver_count,
    cl.bronze_count,
    cl.total_trophies,
    cl.total_games,
    cl.possible_platinum,
    cl.possible_gold,
    cl.possible_silver,
    cl.possible_bronze,
    ls.prev_rank as previous_rank,
    CASE 
      WHEN ls.prev_rank IS NULL THEN 0
      ELSE (ls.prev_rank - cl.current_rank::integer)
    END as rank_change,
    (ls.prev_rank IS NULL) as is_new
  FROM current_leaderboard cl
  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
  ORDER BY cl.current_rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;


ALTER FUNCTION "public"."get_psn_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_rarest_achievement_v2"("p_user_id" "uuid") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "platform_achievement_id" "text", "earned_at" timestamp with time zone, "rarity_global" numeric, "achievement_name" "text", "achievement_icon_url" "text", "game_name" "text", "game_cover_url" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    gt.name as game_name,
    COALESCE(gt.proxied_cover_url, gt.cover_url) as game_cover_url
  FROM user_achievements ua
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  JOIN game_titles gt ON 
    ua.platform_id = gt.platform_id 
    AND ua.platform_game_id = gt.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
    AND a.rarity_global IS NOT NULL
  ORDER BY a.rarity_global ASC
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_rarest_achievement_v2"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_recent_notable_achievements_v2"("p_user_id" "uuid", "p_limit" integer DEFAULT 10) RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "platform_achievement_id" "text", "earned_at" timestamp with time zone, "rarity_global" numeric, "achievement_name" "text", "achievement_icon_url" "text", "game_name" "text", "game_cover_url" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    gt.name as game_name,
    COALESCE(gt.proxied_cover_url, gt.cover_url) as game_cover_url
  FROM user_achievements ua
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  JOIN game_titles gt ON 
    ua.platform_id = gt.platform_id 
    AND ua.platform_game_id = gt.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
    AND a.rarity_global IS NOT NULL
    AND a.rarity_global < 15.0
  ORDER BY ua.earned_at DESC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_recent_notable_achievements_v2"("p_user_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_steam_leaderboard"("limit_count" integer DEFAULT 100) RETURNS TABLE("user_id" "uuid", "display_name" "text", "avatar_url" "text", "score" bigint, "games_count" bigint)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    COALESCE(p.steam_display_name, p.display_name),
    p.steam_avatar_url,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as total_games
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
  WHERE p.show_on_leaderboard = true
    AND p.steam_id IS NOT NULL
  GROUP BY p.id, p.steam_display_name, p.display_name, p.steam_avatar_url
  HAVING COUNT(DISTINCT ua.id) > 0
  ORDER BY achievement_count DESC, total_games DESC
  LIMIT limit_count;
END;
$$;


ALTER FUNCTION "public"."get_steam_leaderboard"("limit_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_steam_leaderboard_with_movement"("limit_count" integer DEFAULT 100, "offset_count" integer DEFAULT 0) RETURNS TABLE("user_id" "uuid", "display_name" "text", "avatar_url" "text", "achievement_count" bigint, "potential_achievements" bigint, "total_games" bigint, "previous_rank" integer, "rank_change" integer, "is_new" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  WITH current_leaderboard AS (
    SELECT 
      lc.user_id,
      lc.display_name,
      lc.avatar_url,
      lc.achievement_count,
      lc.potential_achievements,
      lc.total_games,
      ROW_NUMBER() OVER (ORDER BY lc.achievement_count DESC, lc.total_games DESC) as current_rank
    FROM steam_leaderboard_cache lc
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM steam_leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.achievement_count,
    cl.potential_achievements,
    cl.total_games,
    ls.prev_rank as previous_rank,
    CASE 
      WHEN ls.prev_rank IS NULL THEN 0
      ELSE (ls.prev_rank - cl.current_rank::integer)
    END as rank_change,
    (ls.prev_rank IS NULL) as is_new
  FROM current_leaderboard cl
  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
  ORDER BY cl.current_rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;


ALTER FUNCTION "public"."get_steam_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_superlative_suggestions_v2"("p_user_id" "uuid", "p_category" "text") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "platform_achievement_id" "text", "earned_at" timestamp with time zone, "score" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Different logic based on category
  IF p_category = 'rarest' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
    ORDER BY a.rarity_global ASC
    LIMIT 10;
    
  ELSIF p_category = 'most_recent' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      EXTRACT(EPOCH FROM ua.earned_at)::NUMERIC as score
    FROM user_achievements ua
    WHERE ua.user_id = p_user_id
    ORDER BY ua.earned_at DESC
    LIMIT 10;
    
  ELSIF p_category = 'platinums' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND ua.platform_id = 1 -- PSN
      AND a.metadata->>'psn_trophy_type' = 'platinum'
      AND a.rarity_global IS NOT NULL
    ORDER BY a.rarity_global ASC
    LIMIT 10;
    
  END IF;
END;
$$;


ALTER FUNCTION "public"."get_superlative_suggestions_v2"("p_user_id" "uuid", "p_category" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_superlative_suggestions_v3"("p_user_id" "uuid", "p_category" "text") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "platform_achievement_id" "text", "earned_at" timestamp with time zone, "score" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Category: hardest - lowest rarity achievements (hardest to get)
  IF p_category = 'hardest' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global > 0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: easiest - highest rarity achievements (most common)
  ELSIF p_category = 'easiest' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
    ORDER BY a.rarity_global DESC
    LIMIT 1;
    
  -- Category: aggravating - achievements with names suggesting difficulty/frustration
  ELSIF p_category = 'aggravating' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 5.0
      AND (
        a.name ILIKE '%difficult%' 
        OR a.name ILIKE '%hard%'
        OR a.name ILIKE '%master%'
        OR a.name ILIKE '%challenge%'
        OR a.description ILIKE '%without dying%'
        OR a.description ILIKE '%no damage%'
      )
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: rage_inducing - very rare + challenging description
  ELSIF p_category = 'rage_inducing' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 3.0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: biggest_grind - game with most achievements unlocked
  ELSIF p_category = 'biggest_grind' THEN
    RETURN QUERY
    WITH game_achievement_counts AS (
      SELECT 
        ua.platform_id,
        ua.platform_game_id,
        COUNT(*) as achievement_count,
        MAX(ua.earned_at) as latest_earned
      FROM user_achievements ua
      WHERE ua.user_id = p_user_id
      GROUP BY ua.platform_id, ua.platform_game_id
      ORDER BY achievement_count DESC
      LIMIT 1
    )
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      gac.achievement_count::NUMERIC as score
    FROM user_achievements ua
    INNER JOIN game_achievement_counts gac ON
      gac.platform_id = ua.platform_id
      AND gac.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND ua.earned_at = gac.latest_earned
    LIMIT 1;
    
  -- Category: most_time - same as biggest_grind (most achievements = most time)
  ELSIF p_category = 'most_time' THEN
    RETURN QUERY
    WITH game_achievement_counts AS (
      SELECT 
        ua.platform_id,
        ua.platform_game_id,
        COUNT(*) as achievement_count,
        MAX(ua.earned_at) as latest_earned
      FROM user_achievements ua
      WHERE ua.user_id = p_user_id
      GROUP BY ua.platform_id, ua.platform_game_id
      ORDER BY achievement_count DESC
      LIMIT 1
    )
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      gac.achievement_count::NUMERIC as score
    FROM user_achievements ua
    INNER JOIN game_achievement_counts gac ON
      gac.platform_id = ua.platform_id
      AND gac.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND ua.earned_at = gac.latest_earned
    LIMIT 1;
    
  -- Category: rng_nightmare - ultra rare (< 1%)
  ELSIF p_category = 'rng_nightmare' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 1.0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: never_again - rare achievement from a challenging game
  ELSIF p_category = 'never_again' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 2.0
    ORDER BY a.rarity_global ASC, ua.earned_at DESC
    LIMIT 1;
    
  -- Category: most_proud - platinum trophies (if any), else rarest achievement
  ELSIF p_category = 'most_proud' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND (
        a.metadata->>'psn_trophy_type' = 'platinum'
        OR a.rarity_global < 5.0
      )
    ORDER BY 
      (a.metadata->>'psn_trophy_type' = 'platinum') DESC,
      a.rarity_global ASC
    LIMIT 1;
    
  -- Category: clutch - recent rare achievement (clutch moment)
  ELSIF p_category = 'clutch' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 10.0
    ORDER BY ua.earned_at DESC
    LIMIT 1;
    
  -- Category: cozy_comfort - common/easy achievement (comfort game)
  ELSIF p_category = 'cozy_comfort' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global > 50.0
    ORDER BY a.rarity_global DESC, ua.earned_at DESC
    LIMIT 1;
    
  -- Category: hidden_gem - rare game (fewer people have played it)
  ELSIF p_category = 'hidden_gem' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 15.0
      AND a.rarity_global > 1.0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Default: return rarest achievement
  ELSE
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  END IF;
END;
$$;


ALTER FUNCTION "public"."get_superlative_suggestions_v3"("p_user_id" "uuid", "p_category" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_superlative_suggestions_v3"("p_user_id" "uuid", "p_category" "text") IS 'Get smart suggestions for superlative categories with intelligent logic for each of the 12 types';



CREATE OR REPLACE FUNCTION "public"."get_sweatiest_platinum_v2"("p_user_id" "uuid") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "platform_achievement_id" "text", "earned_at" timestamp with time zone, "rarity_global" numeric, "achievement_name" "text", "achievement_icon_url" "text", "game_name" "text", "game_cover_url" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    gt.name as game_name,
    COALESCE(gt.proxied_cover_url, gt.cover_url) as game_cover_url
  FROM user_achievements ua
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  JOIN game_titles gt ON 
    ua.platform_id = gt.platform_id 
    AND ua.platform_game_id = gt.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
    AND a.rarity_global IS NOT NULL
    AND (a.tier = 'platinum' OR a.is_rare = true)
  ORDER BY a.rarity_global ASC
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_sweatiest_platinum_v2"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unread_activity_count"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM activity_feed af
    WHERE af.is_visible = true
      AND af.expires_at >= CURRENT_DATE
      AND af.created_at > COALESCE(
        (SELECT last_viewed_at FROM activity_feed_views WHERE user_id = p_user_id),
        '1970-01-01'::TIMESTAMPTZ
      )
      -- Removed: AND af.user_id != p_user_id
      -- Now includes user's own stories in unread count
  );
END;
$$;


ALTER FUNCTION "public"."get_unread_activity_count"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_unread_activity_count"("p_user_id" "uuid") IS 'Returns count of unread activity feed stories for a user';



CREATE OR REPLACE FUNCTION "public"."get_user_achievements_for_game"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_id" "text", "p_search_query" "text" DEFAULT NULL::"text") RETURNS TABLE("platform_achievement_id" "text", "achievement_name" "text", "game_name" "text", "cover_url" "text", "icon_url" "text", "rarity_global" numeric, "earned_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.platform_achievement_id,
    a.name as achievement_name,
    g.name as game_name,
    g.cover_url,
    a.icon_url,
    a.rarity_global,
    ua.earned_at
  FROM user_achievements ua
  INNER JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  INNER JOIN games g ON
    g.platform_id = ua.platform_id
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id = p_platform_id
    AND ua.platform_game_id = p_platform_game_id
    AND (p_search_query IS NULL OR a.name ILIKE '%' || p_search_query || '%')
  ORDER BY ua.earned_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_user_achievements_for_game"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_id" "text", "p_search_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_completions"("p_user_id" "uuid") RETURNS TABLE("xbox_complete" integer, "steam_perfect" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(CASE WHEN pl.code = 'XBOXONE' AND ug.completion_percent = 100 THEN 1 END)::INT as xbox_complete,
    COUNT(CASE WHEN pl.code IN ('Steam') AND ug.completion_percent = 100 THEN 1 END)::INT as steam_perfect
  FROM user_games ug
  JOIN platforms pl ON ug.platform_id = pl.id
  WHERE ug.user_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_user_completions"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_games_for_platform"("p_user_id" "uuid", "p_platform_id" bigint, "p_search_query" "text" DEFAULT NULL::"text") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "game_name" "text", "cover_url" "text", "achievement_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    g.platform_id,
    g.platform_game_id,
    g.name as game_name,
    g.cover_url,
    COUNT(ua.platform_achievement_id) as achievement_count
  FROM user_achievements ua
  INNER JOIN games g ON 
    g.platform_id = ua.platform_id 
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id = p_platform_id
    AND (p_search_query IS NULL OR g.name ILIKE '%' || p_search_query || '%')
  GROUP BY g.platform_id, g.platform_game_id, g.name, g.cover_url
  ORDER BY g.name;
END;
$$;


ALTER FUNCTION "public"."get_user_games_for_platform"("p_user_id" "uuid", "p_platform_id" bigint, "p_search_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") RETURNS TABLE("group_id" "text", "name" "text", "cover_url" "text", "proxied_cover_url" "text", "platforms" "jsonb"[], "total_statusxp" numeric, "avg_completion" numeric, "last_played_at" timestamp with time zone, "game_title_ids" bigint[])
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH game_statusxp AS (
    -- Calculate StatusXP per game by summing earned achievements' base_status_xp
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      SUM(a.base_status_xp)::INTEGER as statusxp,
      MIN(a.rarity_global) as rarest_achievement_rarity
    FROM user_achievements ua
    JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id 
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.include_in_score = true
    GROUP BY ua.platform_id, ua.platform_game_id
  ),
  game_scores AS (
    -- Get current_score from user_progress and calculate total_score from achievements
    SELECT 
      up.platform_id,
      up.platform_game_id,
      up.current_score,
      COALESCE(SUM(a.score_value), 0) AS total_score
    FROM user_progress up
    LEFT JOIN achievements a ON 
      a.platform_id = up.platform_id 
      AND a.platform_game_id = up.platform_game_id
    WHERE up.user_id = p_user_id
    GROUP BY up.platform_id, up.platform_game_id, up.current_score
  )
  SELECT 
    ('group_' || ug.game_title_id::TEXT) as group_id,
    ug.game_title as name,
    g.cover_url,
    CASE 
      WHEN g.cover_url LIKE '%cloudfront%' OR g.cover_url LIKE '%supabase%' 
      THEN g.cover_url
      ELSE NULL
    END as proxied_cover_url,
    ARRAY[jsonb_build_object(
      'code', LOWER(
        CASE 
          WHEN p.code IN ('PS3', 'PS4', 'PS5', 'PSVITA') THEN 'psn'
          WHEN p.code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX', 'Xbox') THEN 'xbox'
          WHEN p.code = 'Steam' THEN 'steam'
          ELSE 'unknown'
        END
      ),
      'completion', ug.completion_percent,
      'statusxp', COALESCE(gs.statusxp, 0),
      'game_title_id', ug.game_title_id,
      'platform_id', ug.platform_id,
      'platform_game_id', g.platform_game_id,
      'earned_trophies', ug.earned_trophies,
      'total_trophies', ug.total_trophies,
      'bronze_trophies', ug.bronze_trophies,
      'silver_trophies', ug.silver_trophies,
      'gold_trophies', ug.gold_trophies,
      'platinum_trophies', ug.platinum_trophies,
      'xbox_achievements_earned', ug.earned_trophies,
      'xbox_total_achievements', ug.total_trophies,
      'current_score', COALESCE(gsc.current_score, 0),
      'total_score', COALESCE(gsc.total_score, 0),
      'rarest_achievement_rarity', gs.rarest_achievement_rarity,
      'last_played_at', ug.last_played_at,
      'last_trophy_earned_at', COALESCE(
        CASE WHEN ug.platform_id = 1 THEN ug.last_trophy_earned_at ELSE NULL END,
        (
          SELECT MAX(ua.earned_at) 
          FROM user_achievements ua
          WHERE ua.user_id = p_user_id
            AND ua.platform_id = ug.platform_id
            AND ua.platform_game_id = g.platform_game_id
        )
      )
    )] as platforms,
    COALESCE(gs.statusxp, 0)::NUMERIC as total_statusxp,
    COALESCE(ug.completion_percent, 0) as avg_completion,
    COALESCE(
      CASE WHEN ug.platform_id = 1 THEN ug.last_trophy_earned_at ELSE NULL END,
      (
        SELECT MAX(ua.earned_at) 
        FROM user_achievements ua
        WHERE ua.user_id = p_user_id
          AND ua.platform_id = ug.platform_id
          AND ua.platform_game_id = g.platform_game_id
      ),
      ug.last_played_at
    ) as last_played_at,
    ARRAY[ug.game_title_id] as game_title_ids
  FROM user_games ug
  LEFT JOIN user_progress up ON up.user_id = ug.user_id 
    AND up.platform_id = ug.platform_id
    AND (('x'::text || substr(md5((up.platform_id::text || '_'::text) || up.platform_game_id), 1, 15)))::bit(60)::bigint = ug.game_title_id
  LEFT JOIN games g ON g.platform_id = up.platform_id 
    AND g.platform_game_id = up.platform_game_id
  LEFT JOIN platforms p ON p.id = ug.platform_id
  LEFT JOIN game_statusxp gs ON gs.platform_id = ug.platform_id 
    AND gs.platform_game_id = g.platform_game_id
  LEFT JOIN game_scores gsc ON gsc.platform_id = ug.platform_id
    AND gsc.platform_game_id = g.platform_game_id
  WHERE ug.user_id = p_user_id
  ORDER BY 
    COALESCE(
      CASE WHEN ug.platform_id = 1 THEN ug.last_trophy_earned_at ELSE NULL END,
      (
        SELECT MAX(ua.earned_at) 
        FROM user_achievements ua
        WHERE ua.user_id = p_user_id
          AND ua.platform_id = ug.platform_id
          AND ua.platform_game_id = g.platform_game_id
      ),
      ug.last_played_at
    ) DESC NULLS LAST,
    ug.game_title;
END;
$$;


ALTER FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") IS 'Returns user games grouped by title with StatusXP, Xbox gamerscore (current and total), and rarest achievement rarity. Fixed Jan 31, 2026 - added current_score, total_score (calculated from achievements.score_value), rarest_achievement_rarity.';



CREATE OR REPLACE FUNCTION "public"."get_user_psn_rank"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_rank INT;
  v_user_platinum INT;
  v_user_gold INT;
  v_user_silver INT;
  v_user_bronze INT;
BEGIN
  -- Get current user's trophy counts
  SELECT 
    COALESCE(SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END), 0)
  INTO v_user_platinum, v_user_gold, v_user_silver, v_user_bronze
  FROM user_achievements ua
  JOIN achievements a ON a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id IN (1, 2, 5, 9); -- PS3, PS4, PS5, PSVITA
  
  -- Return NULL if user has no PSN trophies
  IF v_user_platinum = 0 AND v_user_gold = 0 AND v_user_silver = 0 AND v_user_bronze = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Count users ranked better (same ORDER BY logic as view)
  SELECT COUNT(*) + 1 INTO v_rank
  FROM (
    SELECT ua.user_id,
      SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) as platinum_count,
      SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END) as gold_count,
      SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END) as silver_count,
      SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END) as bronze_count
    FROM user_achievements ua
    JOIN achievements a ON a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id 
      AND a.platform_achievement_id = ua.platform_achievement_id
    JOIN profiles p ON p.id = ua.user_id
    WHERE ua.platform_id IN (1, 2, 5, 9)
      AND p.show_on_leaderboard = true
      AND ua.user_id != p_user_id
    GROUP BY ua.user_id
    HAVING COUNT(*) > 0
  ) ranked_users
  WHERE 
    ranked_users.platinum_count > v_user_platinum OR
    (ranked_users.platinum_count = v_user_platinum AND ranked_users.gold_count > v_user_gold) OR
    (ranked_users.platinum_count = v_user_platinum AND ranked_users.gold_count = v_user_gold AND ranked_users.silver_count > v_user_silver) OR
    (ranked_users.platinum_count = v_user_platinum AND ranked_users.gold_count = v_user_gold AND ranked_users.silver_count = v_user_silver AND ranked_users.bronze_count > v_user_bronze);
  
  RETURN v_rank;
END;
$$;


ALTER FUNCTION "public"."get_user_psn_rank"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_steam_rank"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_rank INT;
  v_user_achievements INT;
BEGIN
  -- Get current user's achievement count
  SELECT COALESCE(COUNT(*), 0)
  INTO v_user_achievements
  FROM user_achievements ua
  WHERE ua.user_id = p_user_id
    AND ua.platform_id = 3; -- Steam
  
  -- Return NULL if user has no Steam achievements
  IF v_user_achievements = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Count users ranked better
  SELECT COUNT(*) + 1 INTO v_rank
  FROM (
    SELECT ua.user_id,
      COUNT(*) as achievement_count
    FROM user_achievements ua
    JOIN profiles p ON p.id = ua.user_id
    WHERE ua.platform_id = 3
      AND p.show_on_leaderboard = true
      AND ua.user_id != p_user_id
    GROUP BY ua.user_id
    HAVING COUNT(*) > 0
  ) ranked_users
  WHERE ranked_users.achievement_count > v_user_achievements;
  
  RETURN v_rank;
END;
$$;


ALTER FUNCTION "public"."get_user_steam_rank"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_trophy_counts"("p_user_id" "uuid") RETURNS TABLE("platinum_count" bigint, "gold_count" bigint, "silver_count" bigint, "bronze_count" bigint)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'platinum') as platinum_count,
    COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'gold') as gold_count,
    COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'silver') as silver_count,
    COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'bronze') as bronze_count
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id IN (1, 2, 5, 9); -- PSN platforms only
END;
$$;


ALTER FUNCTION "public"."get_user_trophy_counts"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_user_trophy_counts"("p_user_id" "uuid") IS 'Counts user trophies by type (platinum/gold/silver/bronze) for activity feed snapshots';



CREATE OR REPLACE FUNCTION "public"."get_user_xbox_rank"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_rank INT;
  v_user_gamerscore INT;
  v_user_achievements INT;
BEGIN
  -- Get current user's gamerscore and achievement count
  SELECT 
    COALESCE(SUM((a.metadata->>'xbox_gamerscore')::int), 0),
    COALESCE(COUNT(*), 0)
  INTO v_user_gamerscore, v_user_achievements
  FROM user_achievements ua
  JOIN achievements a ON a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id IN (10, 11, 12); -- Xbox 360, Xbox One, Xbox Series X
  
  -- Return NULL if user has no Xbox achievements
  IF v_user_gamerscore = 0 AND v_user_achievements = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Count users ranked better
  SELECT COUNT(*) + 1 INTO v_rank
  FROM (
    SELECT ua.user_id,
      SUM((a.metadata->>'xbox_gamerscore')::int) as gamerscore,
      COUNT(*) as achievement_count
    FROM user_achievements ua
    JOIN achievements a ON a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id 
      AND a.platform_achievement_id = ua.platform_achievement_id
    JOIN profiles p ON p.id = ua.user_id
    WHERE ua.platform_id IN (10, 11, 12)
      AND p.show_on_leaderboard = true
      AND ua.user_id != p_user_id
    GROUP BY ua.user_id
    HAVING COUNT(*) > 0
  ) ranked_users
  WHERE 
    ranked_users.gamerscore > v_user_gamerscore OR
    (ranked_users.gamerscore = v_user_gamerscore AND ranked_users.achievement_count > v_user_achievements);
  
  RETURN v_rank;
END;
$$;


ALTER FUNCTION "public"."get_user_xbox_rank"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_xbox_leaderboard"("limit_count" integer DEFAULT 100) RETURNS TABLE("user_id" "uuid", "display_name" "text", "avatar_url" "text", "score" bigint, "games_count" bigint)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as total_games
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'xbox'
  WHERE p.show_on_leaderboard = true
    AND p.xbox_xuid IS NOT NULL
  GROUP BY p.id, p.xbox_gamertag, p.xbox_avatar_url
  HAVING COUNT(DISTINCT ua.id) > 0
  ORDER BY achievement_count DESC, total_games DESC
  LIMIT limit_count;
END;
$$;


ALTER FUNCTION "public"."get_xbox_leaderboard"("limit_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_xbox_leaderboard_with_movement"("limit_count" integer DEFAULT 100, "offset_count" integer DEFAULT 0) RETURNS TABLE("user_id" "uuid", "display_name" "text", "avatar_url" "text", "gamerscore" bigint, "potential_gamerscore" bigint, "achievement_count" bigint, "total_games" bigint, "previous_rank" integer, "rank_change" integer, "is_new" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  WITH current_leaderboard AS (
    SELECT 
      lc.user_id,
      lc.display_name,
      lc.avatar_url,
      lc.gamerscore,
      lc.potential_gamerscore,
      lc.achievement_count,
      lc.total_games,
      ROW_NUMBER() OVER (ORDER BY lc.gamerscore DESC, lc.total_games DESC) as current_rank
    FROM xbox_leaderboard_cache lc
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM xbox_leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.gamerscore,
    cl.potential_gamerscore,
    cl.achievement_count,
    cl.total_games,
    ls.prev_rank as previous_rank,
    CASE 
      WHEN ls.prev_rank IS NULL THEN 0
      ELSE (ls.prev_rank - cl.current_rank::integer)
    END as rank_change,
    (ls.prev_rank IS NULL) as is_new
  FROM current_leaderboard cl
  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
  ORDER BY cl.current_rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;


ALTER FUNCTION "public"."get_xbox_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.profiles (id, username, created_at, updated_at)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    now(),
    now()
  );
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_activity_feed_viewed"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO activity_feed_views (user_id, last_viewed_at)
  VALUES (p_user_id, NOW())
  ON CONFLICT (user_id) 
  DO UPDATE SET last_viewed_at = NOW();
END;
$$;


ALTER FUNCTION "public"."mark_activity_feed_viewed"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."mark_activity_feed_viewed"("p_user_id" "uuid") IS 'Updates last viewed timestamp to clear unread badge';



CREATE OR REPLACE FUNCTION "public"."mark_game_groups_for_refresh"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE game_groups_refresh_queue SET needs_refresh = true WHERE id = 1;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."mark_game_groups_for_refresh"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_duplicate_email_profiles"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  existing_user_id UUID;
  existing_provider TEXT;
BEGIN
  -- Check if another auth.users record exists with same email
  SELECT au.id, au.raw_app_meta_data->>'provider' INTO existing_user_id, existing_provider
  FROM auth.users au
  WHERE LOWER(au.email) = LOWER(NEW.email)
    AND au.id != NEW.id
    AND au.email IS NOT NULL
  LIMIT 1;

  -- If duplicate email found, raise exception to prevent profile creation
  IF existing_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'An account with email % already exists (provider: %). Please sign in with that account instead.', 
      NEW.email, 
      COALESCE(existing_provider, 'email');
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_duplicate_email_profiles"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."prevent_duplicate_email_profiles"() IS 'Prevents duplicate accounts with same email across different auth providers (Apple, Google, email/password)';



CREATE OR REPLACE FUNCTION "public"."recalculate_achievement_rarity"() RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public, pg_temp'
    AS $$
BEGIN
  UPDATE public.achievements
  SET rarity_band = CASE
          WHEN rarity_global IS NULL THEN 'COMMON'
          WHEN rarity_global > 25 THEN 'COMMON'
          WHEN rarity_global > 10 THEN 'UNCOMMON'
          WHEN rarity_global > 5 THEN 'RARE'
          WHEN rarity_global > 1 THEN 'VERY_RARE'
          ELSE 'ULTRA_RARE'
      END,
      rarity_multiplier = CASE
          WHEN rarity_global IS NULL THEN 1.00
          WHEN rarity_global > 25 THEN 1.00
          WHEN rarity_global > 10 THEN 1.25
          WHEN rarity_global > 5 THEN 1.75
          WHEN rarity_global > 1 THEN 2.25
          ELSE 3.00
      END,
      base_status_xp = CASE
          WHEN include_in_score = false THEN 0
          WHEN rarity_global IS NULL THEN 0.5
          WHEN rarity_global > 25 THEN 0.5
          WHEN rarity_global > 10 THEN 0.65
          WHEN rarity_global > 5 THEN 0.9
          WHEN rarity_global > 1 THEN 1.15
          ELSE 1.5
      END
  WHERE rarity_global IS NOT NULL;
END;
$$;


ALTER FUNCTION "public"."recalculate_achievement_rarity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_user_progress_for_games"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_ids" "text"[]) RETURNS "void"
    LANGUAGE "sql"
    AS $$
  INSERT INTO public.user_progress (
    user_id, platform_id, platform_game_id,
    achievements_earned, total_achievements, completion_percentage,
    last_achievement_earned_at, synced_at
  )
  SELECT
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    COUNT(*) AS achievements_earned,
    COUNT(a.*) AS total_achievements,
    CASE WHEN COUNT(a.*) = 0 THEN 0
         ELSE (COUNT(*)::numeric / COUNT(a.*)::numeric) * 100
    END AS completion_percentage,
    MAX(ua.earned_at) AS last_achievement_earned_at,
    now() AS synced_at
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON (a.platform_id, a.platform_game_id, a.platform_achievement_id)
     = (ua.platform_id, ua.platform_game_id, ua.platform_achievement_id)
  WHERE ua.user_id = p_user_id
    AND ua.platform_id = p_platform_id
    AND ua.platform_game_id = ANY(p_platform_game_ids)
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
  ON CONFLICT (user_id, platform_id, platform_game_id)
  DO UPDATE SET
    achievements_earned = EXCLUDED.achievements_earned,
    total_achievements = EXCLUDED.total_achievements,
    completion_percentage = EXCLUDED.completion_percentage,
    last_achievement_earned_at = EXCLUDED.last_achievement_earned_at,
    synced_at = now();
$$;


ALTER FUNCTION "public"."recompute_user_progress_for_games"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_ids" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_game_groups"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  processed_ids BIGINT[] := ARRAY[]::BIGINT[];
  current_game RECORD;
  similar_game RECORD;
  group_games BIGINT[];
  group_platforms TEXT[];
  group_key TEXT;
BEGIN
  -- Clear existing groups
  TRUNCATE game_groups;
  
  -- Iterate through all game_titles
  FOR current_game IN 
    SELECT DISTINCT gt.id, gt.name, gt.psn_npwr_id, gt.xbox_title_id, gt.steam_app_id
    FROM game_titles gt
    WHERE EXISTS (SELECT 1 FROM achievements WHERE game_title_id = gt.id)
    ORDER BY gt.id
  LOOP
    -- Skip if already processed
    IF current_game.id = ANY(processed_ids) THEN
      CONTINUE;
    END IF;
    
    -- Start new group with current game
    group_games := ARRAY[current_game.id];
    group_platforms := ARRAY[]::TEXT[];
    
    -- Determine platform for current game
    IF current_game.psn_npwr_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'psn');
    END IF;
    IF current_game.xbox_title_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'xbox');
    END IF;
    IF current_game.steam_app_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'steam');
    END IF;
    
    -- Find similar games (>90% achievement match)
    FOR similar_game IN
      SELECT gt2.id, gt2.psn_npwr_id, gt2.xbox_title_id, gt2.steam_app_id
      FROM game_titles gt2
      WHERE gt2.id > current_game.id
        AND BTRIM(gt2.name, E' \n\r\t') ILIKE BTRIM(current_game.name, E' \n\r\t')
        AND calculate_achievement_similarity(current_game.id, gt2.id) >= 90
    LOOP
      -- Add to group
      group_games := array_append(group_games, similar_game.id);
      
      -- Add platform
      IF similar_game.psn_npwr_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'psn');
      END IF;
      IF similar_game.xbox_title_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'xbox');
      END IF;
      IF similar_game.steam_app_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'steam');
      END IF;
    END LOOP;
    
    -- Mark all games in group as processed
    processed_ids := processed_ids || group_games;
    
    -- Create stable group key
    group_key := 'group_' || (SELECT MIN(id) FROM UNNEST(group_games) AS id)::TEXT;
    
    -- Insert group
    INSERT INTO game_groups (group_key, game_title_ids, primary_game_id, platforms)
    VALUES (group_key, group_games, current_game.id, array_remove(ARRAY(SELECT DISTINCT unnest(group_platforms)), NULL));
  END LOOP;
  
  -- Mark refresh as complete
  UPDATE game_groups_refresh_queue 
  SET needs_refresh = false, 
      last_refresh_at = NOW();
  
  RAISE NOTICE 'Refreshed % game groups', (SELECT COUNT(*) FROM game_groups);
END;
$$;


ALTER FUNCTION "public"."refresh_game_groups"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_game_groups_if_needed"() RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  needs_refresh_flag BOOLEAN;
BEGIN
  SELECT needs_refresh INTO needs_refresh_flag
  FROM game_groups_refresh_queue
  LIMIT 1;
  
  IF needs_refresh_flag THEN
    PERFORM refresh_game_groups();
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$;


ALTER FUNCTION "public"."refresh_game_groups_if_needed"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_grouped_games_cache"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY grouped_games_cache;
END;
$$;


ALTER FUNCTION "public"."refresh_grouped_games_cache"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_leaderboard_cache"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Delegate to the canonical StatusXP refresh (uses user_achievements + calculate_statusxp_with_stacks)
  PERFORM public.refresh_statusxp_leaderboard();
END;
$$;


ALTER FUNCTION "public"."refresh_leaderboard_cache"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_leaderboard_global_cache"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RAISE NOTICE 'Global leaderboard cache is a view - automatically up to date';
END;
$$;


ALTER FUNCTION "public"."refresh_leaderboard_global_cache"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_psn_leaderboard_cache"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY psn_leaderboard_cache;
  RAISE NOTICE 'PSN leaderboard cache refreshed at %', now();
END;
$$;


ALTER FUNCTION "public"."refresh_psn_leaderboard_cache"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_statusxp_leaderboard"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO leaderboard_cache (user_id, total_statusxp, potential_statusxp, total_game_entries, last_updated)
  SELECT 
    p.id as user_id,
    COALESCE(game_totals.total_statusxp, 0) as total_statusxp,
    COALESCE(potential_totals.potential_statusxp, 0) as potential_statusxp,
    COALESCE(game_totals.total_games, 0) as total_game_entries,
    NOW() as last_updated
  FROM profiles p
  LEFT JOIN (
    SELECT 
      ua.user_id,
      COUNT(DISTINCT (ua.platform_id, ua.platform_game_id)) as total_games,
      SUM(statusxp_effective) as total_statusxp
    FROM user_achievements ua
    JOIN LATERAL (
      SELECT statusxp_effective
      FROM calculate_statusxp_with_stacks(ua.user_id)
      WHERE platform_id = ua.platform_id
        AND platform_game_id = ua.platform_game_id
      LIMIT 1
    ) calc ON true
    GROUP BY ua.user_id
  ) game_totals ON game_totals.user_id = p.id
  LEFT JOIN (
    SELECT 
      up.user_id,
      SUM((up.metadata->>'max_score')::bigint) as potential_statusxp
    FROM user_progress up
    WHERE (up.metadata->>'max_score') IS NOT NULL
    GROUP BY up.user_id
  ) potential_totals ON potential_totals.user_id = p.id
  WHERE p.show_on_leaderboard = true
    AND p.merged_into_user_id IS NULL
  ON CONFLICT (user_id) 
  DO UPDATE SET
    total_statusxp = EXCLUDED.total_statusxp,
    potential_statusxp = EXCLUDED.potential_statusxp,
    total_game_entries = EXCLUDED.total_game_entries,
    last_updated = EXCLUDED.last_updated;
END;
$$;


ALTER FUNCTION "public"."refresh_statusxp_leaderboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_statusxp_leaderboard_for_user"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- First, check if user should be on leaderboard
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = p_user_id 
    AND show_on_leaderboard = true 
    AND merged_into_user_id IS NULL
  ) THEN
    -- Remove them if they shouldn't be there
    DELETE FROM leaderboard_cache WHERE user_id = p_user_id;
    RETURN;
  END IF;

  -- Rest of the function unchanged...
  INSERT INTO public.leaderboard_cache (user_id, total_statusxp, potential_statusxp, total_game_entries, last_updated)
  SELECT 
    p.id as user_id,
    COALESCE(game_totals.total_statusxp, 0) as total_statusxp,
    COALESCE(potential_totals.potential_statusxp, 0) as potential_statusxp,
    COALESCE(game_totals.total_games, 0) as total_game_entries,
    NOW() as last_updated
  FROM public.profiles p
  LEFT JOIN LATERAL (
    SELECT 
      COUNT(*)::integer as total_games,
      COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp
    FROM public.calculate_statusxp_with_stacks(p.id)
  ) game_totals ON true
  LEFT JOIN LATERAL (
    SELECT 
      COALESCE(SUM(a.base_status_xp), 0)::bigint as potential_statusxp
    FROM (
      SELECT DISTINCT platform_id, platform_game_id
      FROM user_achievements
      WHERE user_id = p.id
    ) user_games
    JOIN achievements a 
      ON a.platform_id = user_games.platform_id 
      AND a.platform_game_id = user_games.platform_game_id
    WHERE a.include_in_score = true
  ) potential_totals ON true
  WHERE p.id = p_user_id
    AND COALESCE(game_totals.total_statusxp, 0) > 0
  ON CONFLICT (user_id) 
  DO UPDATE SET
    total_statusxp = EXCLUDED.total_statusxp,
    potential_statusxp = EXCLUDED.potential_statusxp,
    total_game_entries = EXCLUDED.total_game_entries,
    last_updated = EXCLUDED.last_updated;

  -- If user has zero StatusXP, ensure they are removed
  DELETE FROM leaderboard_cache
  WHERE user_id = p_user_id
    AND COALESCE(total_statusxp, 0) = 0;
END;
$$;


ALTER FUNCTION "public"."refresh_statusxp_leaderboard_for_user"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."snapshot_leaderboard"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public.leaderboard_history (user_id, rank, total_statusxp, total_game_entries, snapshot_at)
  SELECT 
    lc.user_id,
    ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC)::integer as rank,
    lc.total_statusxp,
    lc.total_game_entries,
    now()
  FROM public.leaderboard_cache lc
  JOIN public.profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true
    AND lc.total_statusxp > 0;
END;
$$;


ALTER FUNCTION "public"."snapshot_leaderboard"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."snapshot_leaderboard"() IS 'Creates a snapshot of current leaderboard rankings. Should be called daily via pg_cron.';



CREATE OR REPLACE FUNCTION "public"."snapshot_psn_leaderboard"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO psn_leaderboard_history (user_id, snapshot_at, rank, platinum_count, total_games)
  SELECT 
    user_id,
    now(),
    ROW_NUMBER() OVER (ORDER BY platinum_count DESC, gold_count DESC, silver_count DESC) as rank,
    platinum_count,
    total_games
  FROM psn_leaderboard_cache
  ORDER BY rank;
  
  RAISE NOTICE 'PSN leaderboard snapshot created at %', now();
END;
$$;


ALTER FUNCTION "public"."snapshot_psn_leaderboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."snapshot_steam_leaderboard"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO steam_leaderboard_history (user_id, snapshot_at, rank, achievement_count, total_games)
  SELECT 
    user_id,
    now(),
    ROW_NUMBER() OVER (ORDER BY achievement_count DESC, total_games DESC) as rank,
    achievement_count,
    total_games
  FROM steam_leaderboard_cache
  ORDER BY rank;
  
  RAISE NOTICE 'Steam leaderboard snapshot created at %', now();
END;
$$;


ALTER FUNCTION "public"."snapshot_steam_leaderboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."snapshot_xbox_leaderboard"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO xbox_leaderboard_history (user_id, snapshot_at, rank, gamerscore, achievement_count, total_games)
  SELECT 
    user_id,
    now(),
    ROW_NUMBER() OVER (ORDER BY gamerscore DESC, total_games DESC) as rank,
    gamerscore,
    achievement_count,
    total_games
  FROM xbox_leaderboard_cache
  ORDER BY rank;
  
  RAISE NOTICE 'Xbox leaderboard snapshot created at %', now();
END;
$$;


ALTER FUNCTION "public"."snapshot_xbox_leaderboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_calculate_statusxp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Calculate raw StatusXP from all earned achievements
  NEW.statusxp_raw := COALESCE((
    SELECT SUM(a.base_status_xp * a.rarity_multiplier)
    FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = NEW.user_id
      AND a.game_title_id = NEW.game_title_id
      AND a.include_in_score = true
  ), 0);

  -- Apply stack multiplier for effective score
  NEW.statusxp_effective := NEW.statusxp_raw * COALESCE(NEW.stack_multiplier, 1.0);

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_calculate_statusxp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_refresh_leaderboards_on_sync"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Refresh all leaderboards after achievement sync completes
  PERFORM auto_refresh_all_leaderboards();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_refresh_leaderboards_on_sync"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unlock_achievement_if_new"("p_user_id" "uuid", "p_achievement_id" "text", "p_unlocked_at" timestamp with time zone DEFAULT "now"()) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Check if achievement already exists
  SELECT EXISTS(
    SELECT 1 FROM user_meta_achievements 
    WHERE user_id = p_user_id AND achievement_id = p_achievement_id
  ) INTO v_exists;
  
  -- If it doesn't exist, insert it
  IF NOT v_exists THEN
    INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
    VALUES (p_user_id, p_achievement_id, p_unlocked_at);
    RETURN TRUE;
  END IF;
  
  -- Already exists, return false
  RETURN FALSE;
END;
$$;


ALTER FUNCTION "public"."unlock_achievement_if_new"("p_user_id" "uuid", "p_achievement_id" "text", "p_unlocked_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_display_case_items_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public, pg_temp'
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_display_case_items_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_flex_room_data_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public, pg_temp'
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_flex_room_data_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_flex_room_last_updated"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.last_updated = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_flex_room_last_updated"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_leaderboard_on_achievements_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM public.refresh_statusxp_leaderboard_for_user(OLD.user_id);
  ELSE
    PERFORM public.refresh_statusxp_leaderboard_for_user(NEW.user_id);
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_leaderboard_on_achievements_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_leaderboard_on_progress_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  PERFORM public.refresh_leaderboard_cache();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_leaderboard_on_progress_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_trophy_help_request_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_trophy_help_request_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public, pg_temp'
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_user_achievements_batch"("p_rows" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- p_rows is a JSON array of objects:
  -- {user_id, platform_id, platform_game_id, platform_achievement_id, earned_at}
  INSERT INTO public.user_achievements (
    user_id, platform_id, platform_game_id, platform_achievement_id, earned_at, synced_at
  )
  SELECT
    (r->>'user_id')::uuid,
    (r->>'platform_id')::bigint,
    (r->>'platform_game_id')::text,
    (r->>'platform_achievement_id')::text,
    (r->>'earned_at')::timestamptz,
    now()
  FROM jsonb_array_elements(p_rows) r
  ON CONFLICT (user_id, platform_id, platform_game_id, platform_achievement_id)
  DO UPDATE SET
    earned_at = LEAST(public.user_achievements.earned_at, EXCLUDED.earned_at),
    synced_at = now();
END;
$$;


ALTER FUNCTION "public"."upsert_user_achievements_batch"("p_rows" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."achievement_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "achievement_id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "comment_text" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_hidden" boolean DEFAULT false,
    "is_flagged" boolean DEFAULT false,
    "flag_count" integer DEFAULT 0,
    "platform_id" bigint NOT NULL,
    "platform_game_id" "text" NOT NULL,
    "platform_achievement_id" "text" NOT NULL
);


ALTER TABLE "public"."achievement_comments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."achievement_comments"."achievement_id" IS 'DEPRECATED: Use (platform_id, platform_game_id, platform_achievement_id) composite FK instead. Will be removed in future migration.';



COMMENT ON COLUMN "public"."achievement_comments"."platform_id" IS 'Part of composite FK to achievements (platform_id, platform_game_id, platform_achievement_id)';



COMMENT ON COLUMN "public"."achievement_comments"."platform_game_id" IS 'Part of composite FK to achievements (platform_id, platform_game_id, platform_achievement_id)';



COMMENT ON COLUMN "public"."achievement_comments"."platform_achievement_id" IS 'Part of composite FK to achievements (platform_id, platform_game_id, platform_achievement_id). Initially backfilled from achievement_id::text';



CREATE TABLE IF NOT EXISTS "public"."achievements" (
    "platform_id" bigint NOT NULL,
    "platform_game_id" "text" NOT NULL,
    "platform_achievement_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "icon_url" "text",
    "rarity_global" numeric(5,2),
    "score_value" integer DEFAULT 0,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "base_status_xp_old" numeric(6,2) DEFAULT 10,
    "rarity_multiplier" numeric(4,2) DEFAULT 1.00,
    "include_in_score" boolean DEFAULT true,
    "is_platinum" boolean DEFAULT false,
    "proxied_icon_url" "text",
    "base_status_xp" numeric(6,2)
);


ALTER TABLE "public"."achievements" OWNER TO "postgres";


COMMENT ON TABLE "public"."achievements" IS 'Platform-specific achievements. Composite PK ensures uniqueness.';



CREATE TABLE IF NOT EXISTS "public"."activity_feed" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "story_text" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "change_type" "text",
    "old_value" integer,
    "new_value" integer,
    "change_amount" integer,
    "gold_count" integer DEFAULT 0,
    "silver_count" integer DEFAULT 0,
    "bronze_count" integer DEFAULT 0,
    "game_title" "text",
    "platform_id" integer,
    "username" "text" NOT NULL,
    "avatar_url" "text",
    "event_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" "date" DEFAULT ((CURRENT_DATE + '7 days'::interval))::"date" NOT NULL,
    "is_visible" boolean DEFAULT true NOT NULL,
    "ai_model" "text" DEFAULT 'gpt-4o-mini'::"text",
    "generation_failed" boolean DEFAULT false NOT NULL,
    CONSTRAINT "activity_feed_check" CHECK (("expires_at" = (("event_date" + '7 days'::interval))::"date")),
    CONSTRAINT "activity_feed_event_type_check" CHECK (("event_type" = ANY (ARRAY['statusxp_gain'::"text", 'platinum_milestone'::"text", 'gamerscore_gain'::"text", 'trophy_detail'::"text", 'steam_achievement_gain'::"text", 'trophy_with_statusxp'::"text"])))
);


ALTER TABLE "public"."activity_feed" OWNER TO "postgres";


COMMENT ON TABLE "public"."activity_feed" IS 'AI-generated stories about user achievements (7-day rolling window)';



COMMENT ON COLUMN "public"."activity_feed"."story_text" IS 'AI-generated announcement with personality';



COMMENT ON COLUMN "public"."activity_feed"."expires_at" IS 'Auto-delete date (event_date + 7 days)';



CREATE SEQUENCE IF NOT EXISTS "public"."activity_feed_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."activity_feed_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."activity_feed_id_seq" OWNED BY "public"."activity_feed"."id";



CREATE TABLE IF NOT EXISTS "public"."activity_feed_views" (
    "user_id" "uuid" NOT NULL,
    "last_viewed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_viewed_id" bigint
);


ALTER TABLE "public"."activity_feed_views" OWNER TO "postgres";


COMMENT ON TABLE "public"."activity_feed_views" IS 'Tracks when users last viewed activity feed for unread counts';



CREATE TABLE IF NOT EXISTS "public"."app_updates" (
    "id" bigint NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "release_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "version" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."app_updates" OWNER TO "postgres";


COMMENT ON TABLE "public"."app_updates" IS 'Stores app update changelog entries for display in settings screen';



ALTER TABLE "public"."app_updates" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."app_updates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."flex_room_data" (
    "user_id" "uuid" NOT NULL,
    "tagline" "text" DEFAULT 'Completionist'::"text",
    "last_updated" timestamp with time zone DEFAULT "now"(),
    "flex_of_all_time_platform_id" bigint,
    "flex_of_all_time_platform_game_id" "text",
    "flex_of_all_time_platform_achievement_id" "text",
    "rarest_flex_platform_id" bigint,
    "rarest_flex_platform_game_id" "text",
    "rarest_flex_platform_achievement_id" "text",
    "most_time_sunk_platform_id" bigint,
    "most_time_sunk_platform_game_id" "text",
    "most_time_sunk_platform_achievement_id" "text",
    "sweatiest_platinum_platform_id" bigint,
    "sweatiest_platinum_platform_game_id" "text",
    "sweatiest_platinum_platform_achievement_id" "text",
    "superlatives" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "profile_id" "uuid" NOT NULL
);


ALTER TABLE "public"."flex_room_data" OWNER TO "postgres";


COMMENT ON COLUMN "public"."flex_room_data"."user_id" IS 'DEPRECATED: Use profile_id instead. Column kept for reference only. FK constraint removed.';



COMMENT ON COLUMN "public"."flex_room_data"."profile_id" IS 'References profiles(id). Replaces user_id (auth.users) for app-domain consistency.';



CREATE TABLE IF NOT EXISTS "public"."game_groups" (
    "id" bigint NOT NULL,
    "group_key" "text" NOT NULL,
    "game_title_ids" bigint[] NOT NULL,
    "primary_game_id" bigint NOT NULL,
    "platforms" "text"[],
    "similarity_score" numeric,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."game_groups" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."game_groups_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."game_groups_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."game_groups_id_seq" OWNED BY "public"."game_groups"."id";



CREATE TABLE IF NOT EXISTS "public"."game_groups_refresh_queue" (
    "id" bigint NOT NULL,
    "needs_refresh" boolean DEFAULT true,
    "last_refresh_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."game_groups_refresh_queue" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."game_groups_refresh_queue_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."game_groups_refresh_queue_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."game_groups_refresh_queue_id_seq" OWNED BY "public"."game_groups_refresh_queue"."id";



CREATE TABLE IF NOT EXISTS "public"."games" (
    "platform_id" bigint NOT NULL,
    "platform_game_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "cover_url" "text",
    "icon_url" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."games" OWNER TO "postgres";


COMMENT ON TABLE "public"."games" IS 'Platform-specific games. Composite PK prevents duplicates.';



COMMENT ON COLUMN "public"."games"."platform_game_id" IS 'xbox_title_id, psn_npwr_id, or steam_app_id depending on platform';



CREATE TABLE IF NOT EXISTS "public"."platforms" (
    "id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "primary_color" "text",
    "accent_color" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."platforms" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."grouped_games_cache" AS
 WITH "distinct_game_platforms" AS (
         SELECT DISTINCT ON (("lower"(TRIM(BOTH FROM "g"."name"))), "g"."platform_id") "lower"(TRIM(BOTH FROM "g"."name")) AS "normalized_name",
            "g"."name",
            "g"."platform_id",
            "g"."platform_game_id",
            "g"."cover_url",
            "p"."code" AS "platform_code",
            "p"."name" AS "platform_name"
           FROM ("public"."games" "g"
             JOIN "public"."platforms" "p" ON (("p"."id" = "g"."platform_id")))
          ORDER BY ("lower"(TRIM(BOTH FROM "g"."name"))), "g"."platform_id", "g"."name"
        ), "game_groups" AS (
         SELECT "dgp"."normalized_name",
            "min"("dgp"."name") AS "display_name",
            ("array_agg"("dgp"."platform_id" ORDER BY
                CASE "dgp"."platform_id"
                    WHEN 1 THEN 1
                    WHEN 11 THEN 2
                    WHEN 5 THEN 3
                    WHEN 2 THEN 4
                    WHEN 12 THEN 5
                    ELSE 99
                END, "dgp"."platform_id"))[1] AS "primary_platform_id",
            ("array_agg"("dgp"."platform_game_id" ORDER BY
                CASE "dgp"."platform_id"
                    WHEN 1 THEN 1
                    WHEN 11 THEN 2
                    WHEN 5 THEN 3
                    WHEN 2 THEN 4
                    WHEN 12 THEN 5
                    ELSE 99
                END, "dgp"."platform_id"))[1] AS "primary_game_id",
            ("array_agg"("dgp"."cover_url" ORDER BY
                CASE "dgp"."platform_id"
                    WHEN 1 THEN 1
                    WHEN 11 THEN 2
                    WHEN 5 THEN 3
                    WHEN 2 THEN 4
                    WHEN 12 THEN 5
                    ELSE 99
                END, "dgp"."platform_id"))[1] AS "primary_cover_url",
            "array_agg"("dgp"."platform_code" ORDER BY "dgp"."platform_id") AS "platforms",
            "array_agg"("dgp"."platform_name" ORDER BY "dgp"."platform_id") AS "platform_names",
            "array_agg"("dgp"."platform_id" ORDER BY "dgp"."platform_id") AS "platform_ids",
            "array_agg"("dgp"."platform_game_id" ORDER BY "dgp"."platform_id") AS "platform_game_ids"
           FROM "distinct_game_platforms" "dgp"
          GROUP BY "dgp"."normalized_name"
        ), "achievement_counts" AS (
         SELECT "lower"(TRIM(BOTH FROM "g"."name")) AS "normalized_name",
            "count"(DISTINCT "a"."platform_achievement_id") AS "total_achievements"
           FROM ("public"."games" "g"
             LEFT JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "g"."platform_id") AND ("a"."platform_game_id" = "g"."platform_game_id"))))
          GROUP BY ("lower"(TRIM(BOTH FROM "g"."name")))
        )
 SELECT "gg"."normalized_name",
    "gg"."display_name" AS "name",
    "gg"."primary_cover_url" AS "cover_url",
    "gg"."primary_platform_id",
    "gg"."primary_game_id",
    "gg"."platforms",
    "gg"."platform_names",
    "gg"."platform_ids",
    "gg"."platform_game_ids",
    (COALESCE("ac"."total_achievements", (0)::bigint))::integer AS "total_achievements"
   FROM ("game_groups" "gg"
     LEFT JOIN "achievement_counts" "ac" ON (("ac"."normalized_name" = "gg"."normalized_name")));


ALTER VIEW "public"."grouped_games_cache" OWNER TO "postgres";


COMMENT ON VIEW "public"."grouped_games_cache" IS 'Game catalog grouped by normalized name. Converted from materialized view to regular view Jan 31, 2026 - always shows fresh game covers without manual refresh.';



CREATE TABLE IF NOT EXISTS "public"."leaderboard_cache" (
    "user_id" "uuid" NOT NULL,
    "total_statusxp" bigint DEFAULT 0 NOT NULL,
    "total_game_entries" integer DEFAULT 0 NOT NULL,
    "last_updated" timestamp with time zone DEFAULT "now"(),
    "potential_statusxp" bigint DEFAULT 0,
    "display_name" "text",
    "avatar_url" "text"
);


ALTER TABLE "public"."leaderboard_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text" NOT NULL,
    "display_name" "text",
    "avatar_url" "text",
    "psn_online_id" "text",
    "xbox_gamertag" "text",
    "steam_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "psn_account_id" "text",
    "psn_npsso_token" "text",
    "psn_access_token" "text",
    "psn_refresh_token" "text",
    "psn_token_expires_at" timestamp with time zone,
    "last_psn_sync_at" timestamp with time zone,
    "psn_sync_status" "text" DEFAULT 'never_synced'::"text",
    "psn_sync_error" "text",
    "psn_sync_progress" integer DEFAULT 0,
    "subscription_tier" "text" DEFAULT 'free'::"text" NOT NULL,
    "subscription_expires_at" timestamp with time zone,
    "psn_avatar_url" "text",
    "psn_is_plus" boolean DEFAULT false,
    "xbox_xuid" "text",
    "xbox_access_token" "text",
    "xbox_refresh_token" "text",
    "xbox_token_expires_at" timestamp with time zone,
    "xbox_sync_status" "text" DEFAULT 'never_synced'::"text",
    "last_xbox_sync_at" timestamp with time zone,
    "xbox_sync_error" "text",
    "xbox_sync_progress" integer DEFAULT 0,
    "xbox_user_hash" "text",
    "steam_sync_status" "text",
    "steam_sync_progress" integer DEFAULT 0,
    "steam_sync_error" "text",
    "last_steam_sync_at" timestamp with time zone,
    "steam_api_key" "text",
    "preferred_display_platform" "text" DEFAULT 'psn'::"text",
    "steam_display_name" "text",
    "xbox_avatar_url" "text",
    "steam_avatar_url" "text",
    "merged_into_user_id" "uuid",
    "merged_at" timestamp with time zone,
    "show_on_leaderboard" boolean DEFAULT true,
    "twitch_user_id" "text",
    CONSTRAINT "profiles_preferred_display_platform_check" CHECK (("preferred_display_platform" = ANY (ARRAY['psn'::"text", 'steam'::"text", 'xbox'::"text"]))),
    CONSTRAINT "profiles_psn_sync_status_check" CHECK (("psn_sync_status" = ANY (ARRAY['never_synced'::"text", 'pending'::"text", 'syncing'::"text", 'success'::"text", 'error'::"text", 'stopped'::"text", 'cancelling'::"text"]))),
    CONSTRAINT "profiles_steam_sync_status_check" CHECK (("steam_sync_status" = ANY (ARRAY['never_synced'::"text", 'pending'::"text", 'syncing'::"text", 'success'::"text", 'error'::"text", 'stopped'::"text", 'cancelling'::"text"]))),
    CONSTRAINT "profiles_subscription_tier_check" CHECK (("subscription_tier" = ANY (ARRAY['free'::"text", 'premium'::"text"]))),
    CONSTRAINT "profiles_xbox_sync_status_check" CHECK (("xbox_sync_status" = ANY (ARRAY['never_synced'::"text", 'pending'::"text", 'syncing'::"text", 'success'::"text", 'error'::"text", 'stopped'::"text", 'cancelling'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles" IS 'Consolidated RLS policies - single policy per operation type';



COMMENT ON COLUMN "public"."profiles"."psn_online_id" IS 'PSN Online ID (username) fetched from PSN API';



COMMENT ON COLUMN "public"."profiles"."psn_account_id" IS 'PlayStation Network account ID';



COMMENT ON COLUMN "public"."profiles"."psn_npsso_token" IS 'Encrypted NPSSO token for PSN authentication';



COMMENT ON COLUMN "public"."profiles"."psn_access_token" IS 'Current PSN API access token';



COMMENT ON COLUMN "public"."profiles"."psn_refresh_token" IS 'PSN refresh token for obtaining new access tokens';



COMMENT ON COLUMN "public"."profiles"."psn_token_expires_at" IS 'Expiration timestamp for the current access token';



COMMENT ON COLUMN "public"."profiles"."last_psn_sync_at" IS 'Last successful PSN trophy sync timestamp';



COMMENT ON COLUMN "public"."profiles"."psn_sync_status" IS 'Current status of PSN sync process';



COMMENT ON COLUMN "public"."profiles"."psn_sync_error" IS 'Error message from last failed sync';



COMMENT ON COLUMN "public"."profiles"."psn_sync_progress" IS 'Percentage progress of current sync (0-100)';



COMMENT ON COLUMN "public"."profiles"."subscription_tier" IS 'User subscription tier: free (24h sync cooldown) or premium (8h sync cooldown)';



COMMENT ON COLUMN "public"."profiles"."subscription_expires_at" IS 'When premium subscription expires (null for free tier)';



COMMENT ON COLUMN "public"."profiles"."psn_avatar_url" IS 'PSN avatar URL (typically medium size)';



COMMENT ON COLUMN "public"."profiles"."psn_is_plus" IS 'Whether user has PlayStation Plus subscription';



COMMENT ON COLUMN "public"."profiles"."xbox_user_hash" IS 'Xbox Live user hash (uhs) required for API authorization headers';



COMMENT ON COLUMN "public"."profiles"."steam_sync_status" IS 'Current status of Steam sync process';



COMMENT ON COLUMN "public"."profiles"."steam_sync_progress" IS 'Sync progress percentage (0-100)';



COMMENT ON COLUMN "public"."profiles"."steam_sync_error" IS 'Error message from last failed sync';



COMMENT ON COLUMN "public"."profiles"."last_steam_sync_at" IS 'Last successful Steam achievement sync timestamp';



COMMENT ON COLUMN "public"."profiles"."steam_api_key" IS 'User Steam Web API key for accessing achievements';



COMMENT ON COLUMN "public"."profiles"."xbox_avatar_url" IS 'Xbox profile avatar URL fetched from Xbox Live API';



COMMENT ON COLUMN "public"."profiles"."steam_avatar_url" IS 'Steam avatar URL (avatarfull) fetched from Steam API';



COMMENT ON COLUMN "public"."profiles"."show_on_leaderboard" IS 'Privacy setting: whether user appears on public leaderboards (default: true)';



COMMENT ON COLUMN "public"."profiles"."twitch_user_id" IS 'Twitch user ID (not username) for linking Twitch subscriptions to premium access';



COMMENT ON CONSTRAINT "profiles_psn_sync_status_check" ON "public"."profiles" IS 'Valid PSN sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user), cancelling (stop requested)';



COMMENT ON CONSTRAINT "profiles_steam_sync_status_check" ON "public"."profiles" IS 'Valid Steam sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user), cancelling (stop requested)';



COMMENT ON CONSTRAINT "profiles_xbox_sync_status_check" ON "public"."profiles" IS 'Valid Xbox sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user), cancelling (stop requested)';



CREATE TABLE IF NOT EXISTS "public"."user_achievements" (
    "user_id" "uuid" NOT NULL,
    "platform_id" bigint NOT NULL,
    "platform_game_id" "text" NOT NULL,
    "platform_achievement_id" "text" NOT NULL,
    "earned_at" timestamp with time zone NOT NULL,
    "synced_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_achievements" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_achievements" IS 'Earned achievements. Composite PK prevents duplicate earnings.';



CREATE OR REPLACE VIEW "public"."leaderboard_global_cache" WITH ("security_invoker"='true') AS
 WITH "user_statusxp" AS (
         SELECT "ua"."user_id",
            "sum"(
                CASE
                    WHEN (("a"."rarity_global" IS NOT NULL) AND ("a"."rarity_global" <= 1.0)) THEN 300
                    WHEN (("a"."rarity_global" IS NOT NULL) AND ("a"."rarity_global" <= 5.0)) THEN 225
                    WHEN (("a"."rarity_global" IS NOT NULL) AND ("a"."rarity_global" <= 10.0)) THEN 175
                    WHEN (("a"."rarity_global" IS NOT NULL) AND ("a"."rarity_global" <= 25.0)) THEN 125
                    WHEN ("a"."rarity_global" IS NOT NULL) THEN 100
                    ELSE 100
                END) AS "statusxp",
            "count"(DISTINCT ROW("a"."platform_id", "a"."platform_game_id", "a"."platform_achievement_id")) AS "total_achievements",
            "count"(DISTINCT ROW("a"."platform_id", "a"."platform_game_id")) AS "total_games"
           FROM ("public"."user_achievements" "ua"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ua"."platform_id") AND ("a"."platform_game_id" = "ua"."platform_game_id") AND ("a"."platform_achievement_id" = "ua"."platform_achievement_id"))))
          GROUP BY "ua"."user_id"
        )
 SELECT "row_number"() OVER (ORDER BY "us"."statusxp" DESC, "us"."total_achievements" DESC) AS "rank",
    "us"."user_id",
    COALESCE("p"."display_name", "p"."username", 'Player'::"text") AS "display_name",
    "p"."avatar_url",
    "us"."statusxp",
    "us"."total_achievements",
    "us"."total_games",
    "now"() AS "updated_at"
   FROM ("user_statusxp" "us"
     JOIN "public"."profiles" "p" ON (("p"."id" = "us"."user_id")))
  WHERE (("p"."show_on_leaderboard" = true) AND ("us"."statusxp" > 0))
  ORDER BY "us"."statusxp" DESC, "us"."total_achievements" DESC;


ALTER VIEW "public"."leaderboard_global_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."leaderboard_history" (
    "user_id" "uuid" NOT NULL,
    "rank" integer NOT NULL,
    "total_statusxp" bigint NOT NULL,
    "total_game_entries" integer DEFAULT 0,
    "snapshot_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."leaderboard_history" OWNER TO "postgres";


COMMENT ON TABLE "public"."leaderboard_history" IS 'Historical snapshots of leaderboard rankings for tracking rank changes over time';



COMMENT ON COLUMN "public"."leaderboard_history"."rank" IS 'User rank at time of snapshot';



COMMENT ON COLUMN "public"."leaderboard_history"."total_statusxp" IS 'Total StatusXP at time of snapshot';



COMMENT ON COLUMN "public"."leaderboard_history"."snapshot_at" IS 'When this snapshot was taken';



CREATE TABLE IF NOT EXISTS "public"."meta_achievements" (
    "id" "text" NOT NULL,
    "category" "text" NOT NULL,
    "default_title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "icon_emoji" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "required_platforms" "text"[]
);


ALTER TABLE "public"."meta_achievements" OWNER TO "postgres";


COMMENT ON COLUMN "public"."meta_achievements"."required_platforms" IS 'Array of platform codes required to earn this achievement. NULL = available to all. Examples: [''psn''], [''xbox''], [''steam''], [''psn'',''xbox'',''steam''] for cross-platform';



CREATE SEQUENCE IF NOT EXISTS "public"."platforms_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."platforms_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."platforms_id_seq" OWNED BY "public"."platforms"."id";



CREATE TABLE IF NOT EXISTS "public"."profile_themes" (
    "id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "background_color" "text",
    "primary_color" "text",
    "accent_color" "text",
    "text_color" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."profile_themes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."profile_themes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."profile_themes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."profile_themes_id_seq" OWNED BY "public"."profile_themes"."id";



CREATE MATERIALIZED VIEW "public"."psn_leaderboard_cache" AS
 WITH "user_earned_trophies" AS (
         SELECT "ua"."user_id",
            "sum"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'bronze'::"text") THEN 1
                    ELSE 0
                END) AS "bronze_count",
            "sum"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'silver'::"text") THEN 1
                    ELSE 0
                END) AS "silver_count",
            "sum"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'gold'::"text") THEN 1
                    ELSE 0
                END) AS "gold_count",
            "sum"(
                CASE
                    WHEN ("a"."is_platinum" = true) THEN 1
                    ELSE 0
                END) AS "platinum_count",
            "count"(*) AS "total_trophies",
            "count"(DISTINCT "a"."platform_game_id") AS "total_games"
           FROM ("public"."user_achievements" "ua"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ua"."platform_id") AND ("a"."platform_game_id" = "ua"."platform_game_id") AND ("a"."platform_achievement_id" = "ua"."platform_achievement_id"))))
          WHERE ("ua"."platform_id" = ANY (ARRAY[(1)::bigint, (2)::bigint, (5)::bigint, (9)::bigint]))
          GROUP BY "ua"."user_id"
        ), "user_possible_trophies" AS (
         SELECT "ug"."user_id",
            "sum"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'bronze'::"text") THEN 1
                    ELSE 0
                END) AS "possible_bronze",
            "sum"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'silver'::"text") THEN 1
                    ELSE 0
                END) AS "possible_silver",
            "sum"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'gold'::"text") THEN 1
                    ELSE 0
                END) AS "possible_gold",
            "sum"(
                CASE
                    WHEN ("a"."is_platinum" = true) THEN 1
                    ELSE 0
                END) AS "possible_platinum"
           FROM (( SELECT DISTINCT "user_achievements"."user_id",
                    "user_achievements"."platform_id",
                    "user_achievements"."platform_game_id"
                   FROM "public"."user_achievements"
                  WHERE ("user_achievements"."platform_id" = ANY (ARRAY[(1)::bigint, (2)::bigint, (5)::bigint, (9)::bigint]))) "ug"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ug"."platform_id") AND ("a"."platform_game_id" = "ug"."platform_game_id"))))
          GROUP BY "ug"."user_id"
        )
 SELECT "uet"."user_id",
    COALESCE("p"."psn_online_id", "p"."display_name", "p"."username", 'Player'::"text") AS "display_name",
    "p"."psn_avatar_url" AS "avatar_url",
    "uet"."bronze_count",
    "uet"."silver_count",
    "uet"."gold_count",
    "uet"."platinum_count",
    COALESCE("upt"."possible_bronze", (0)::bigint) AS "possible_bronze",
    COALESCE("upt"."possible_silver", (0)::bigint) AS "possible_silver",
    COALESCE("upt"."possible_gold", (0)::bigint) AS "possible_gold",
    COALESCE("upt"."possible_platinum", (0)::bigint) AS "possible_platinum",
    "uet"."total_trophies",
    "uet"."total_games",
    "now"() AS "updated_at"
   FROM (("user_earned_trophies" "uet"
     JOIN "public"."profiles" "p" ON (("p"."id" = "uet"."user_id")))
     LEFT JOIN "user_possible_trophies" "upt" ON (("upt"."user_id" = "uet"."user_id")))
  WHERE (("p"."show_on_leaderboard" = true) AND ("uet"."total_trophies" > 0))
  ORDER BY "uet"."platinum_count" DESC, "uet"."gold_count" DESC, "uet"."silver_count" DESC, "uet"."bronze_count" DESC
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."psn_leaderboard_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."psn_leaderboard_history" (
    "user_id" "uuid" NOT NULL,
    "snapshot_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rank" integer NOT NULL,
    "platinum_count" integer NOT NULL,
    "total_games" integer NOT NULL
);


ALTER TABLE "public"."psn_leaderboard_history" OWNER TO "postgres";


COMMENT ON TABLE "public"."psn_leaderboard_history" IS 'Historical snapshots of PSN platinum leaderboard rankings for tracking movement over time';



CREATE TABLE IF NOT EXISTS "public"."psn_sync_logs" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "sync_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "games_processed" integer DEFAULT 0,
    "trophies_synced" integer DEFAULT 0,
    "games_processed_ids" "text"[] DEFAULT '{}'::"text"[],
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "psn_sync_logs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'syncing'::"text", 'completed'::"text", 'failed'::"text"]))),
    CONSTRAINT "psn_sync_logs_sync_type_check" CHECK (("sync_type" = ANY (ARRAY['full'::"text", 'incremental'::"text"])))
);


ALTER TABLE "public"."psn_sync_logs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."psn_sync_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."psn_sync_logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."psn_sync_logs_id_seq" OWNED BY "public"."psn_sync_logs"."id";



CREATE TABLE IF NOT EXISTS "public"."psn_user_trophy_profile" (
    "user_id" "uuid" NOT NULL,
    "psn_trophy_level" integer NOT NULL,
    "psn_trophy_progress" integer NOT NULL,
    "psn_trophy_tier" integer NOT NULL,
    "psn_earned_bronze" integer DEFAULT 0,
    "psn_earned_silver" integer DEFAULT 0,
    "psn_earned_gold" integer DEFAULT 0,
    "psn_earned_platinum" integer DEFAULT 0,
    "last_fetched_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."psn_user_trophy_profile" OWNER TO "postgres";


COMMENT ON TABLE "public"."psn_user_trophy_profile" IS 'PSN account trophy summary and level';



CREATE OR REPLACE VIEW "public"."steam_leaderboard_cache" AS
 WITH "steam_achievement_stats" AS (
         SELECT "ua"."user_id",
            "count"(*) AS "achievement_count",
            "count"(DISTINCT "a"."platform_game_id") AS "total_games"
           FROM ("public"."user_achievements" "ua"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ua"."platform_id") AND ("a"."platform_game_id" = "ua"."platform_game_id") AND ("a"."platform_achievement_id" = "ua"."platform_achievement_id"))))
          WHERE ("ua"."platform_id" = 4)
          GROUP BY "ua"."user_id"
        ), "steam_potential_achievements" AS (
         SELECT "ua"."user_id",
            "count"(DISTINCT "a"."platform_achievement_id") AS "potential_achievements"
           FROM ("public"."user_achievements" "ua"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ua"."platform_id") AND ("a"."platform_game_id" = "ua"."platform_game_id"))))
          WHERE ("ua"."platform_id" = 4)
          GROUP BY "ua"."user_id", "a"."platform_game_id"
        )
 SELECT "sas"."user_id",
    COALESCE("p"."steam_display_name", "p"."display_name", "p"."username", 'Player'::"text") AS "display_name",
    "p"."steam_avatar_url" AS "avatar_url",
    COALESCE("sas"."achievement_count", (0)::bigint) AS "achievement_count",
    (COALESCE("sum"("spa"."potential_achievements"), (0)::numeric))::bigint AS "potential_achievements",
    "sas"."total_games",
    "now"() AS "updated_at"
   FROM (("steam_achievement_stats" "sas"
     JOIN "public"."profiles" "p" ON (("p"."id" = "sas"."user_id")))
     LEFT JOIN "steam_potential_achievements" "spa" ON (("spa"."user_id" = "sas"."user_id")))
  WHERE ("p"."show_on_leaderboard" = true)
  GROUP BY "sas"."user_id", "p"."steam_display_name", "p"."display_name", "p"."username", "p"."steam_avatar_url", "sas"."achievement_count", "sas"."total_games"
  ORDER BY COALESCE("sas"."achievement_count", (0)::bigint) DESC, "sas"."total_games" DESC;


ALTER VIEW "public"."steam_leaderboard_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."steam_leaderboard_history" (
    "user_id" "uuid" NOT NULL,
    "snapshot_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rank" integer NOT NULL,
    "achievement_count" integer NOT NULL,
    "total_games" integer NOT NULL
);


ALTER TABLE "public"."steam_leaderboard_history" OWNER TO "postgres";


COMMENT ON TABLE "public"."steam_leaderboard_history" IS 'Historical snapshots of Steam achievement leaderboard rankings for tracking movement over time';



CREATE TABLE IF NOT EXISTS "public"."steam_sync_logs" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "sync_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "games_processed" integer DEFAULT 0,
    "achievements_synced" integer DEFAULT 0,
    "games_processed_ids" "text"[] DEFAULT '{}'::"text"[],
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "steam_sync_logs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'syncing'::"text", 'completed'::"text", 'failed'::"text"]))),
    CONSTRAINT "steam_sync_logs_sync_type_check" CHECK (("sync_type" = ANY (ARRAY['full'::"text", 'incremental'::"text"])))
);


ALTER TABLE "public"."steam_sync_logs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."steam_sync_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."steam_sync_logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."steam_sync_logs_id_seq" OWNED BY "public"."steam_sync_logs"."id";



CREATE TABLE IF NOT EXISTS "public"."trophy_help_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "game_id" "text" NOT NULL,
    "game_title" "text" NOT NULL,
    "achievement_id" "text" NOT NULL,
    "achievement_name" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "description" "text",
    "availability" "text",
    "platform_username" "text",
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    CONSTRAINT "trophy_help_requests_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'assigned'::"text", 'closed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."trophy_help_requests" OWNER TO "postgres";


COMMENT ON COLUMN "public"."trophy_help_requests"."user_id" IS 'DEPRECATED: Use profile_id instead. Column kept for reference only. FK constraint removed.';



COMMENT ON COLUMN "public"."trophy_help_requests"."profile_id" IS 'References profiles(id). Replaces user_id (auth.users) for app-domain consistency.';



CREATE TABLE IF NOT EXISTS "public"."trophy_help_responses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "request_id" "uuid" NOT NULL,
    "helper_user_id" "uuid" NOT NULL,
    "message" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "helper_profile_id" "uuid" NOT NULL,
    CONSTRAINT "trophy_help_responses_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'declined'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."trophy_help_responses" OWNER TO "postgres";


COMMENT ON COLUMN "public"."trophy_help_responses"."helper_user_id" IS 'DEPRECATED: Use helper_profile_id instead. Column kept for reference only. FK constraint removed.';



COMMENT ON COLUMN "public"."trophy_help_responses"."helper_profile_id" IS 'References profiles(id). Replaces helper_user_id (auth.users) for app-domain consistency.';



CREATE TABLE IF NOT EXISTS "public"."trophy_room_items" (
    "id" bigint NOT NULL,
    "shelf_id" bigint,
    "slot_index" integer NOT NULL,
    "item_type" "text" NOT NULL,
    "trophy_id" bigint,
    "game_title_id" bigint,
    "label_override" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."trophy_room_items" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."trophy_room_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."trophy_room_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."trophy_room_items_id_seq" OWNED BY "public"."trophy_room_items"."id";



CREATE TABLE IF NOT EXISTS "public"."trophy_room_shelves" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "name" "text" NOT NULL,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."trophy_room_shelves" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."trophy_room_shelves_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."trophy_room_shelves_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."trophy_room_shelves_id_seq" OWNED BY "public"."trophy_room_shelves"."id";



CREATE TABLE IF NOT EXISTS "public"."user_ai_credits" (
    "user_id" "uuid" NOT NULL,
    "pack_credits" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_ai_credits" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_ai_credits" IS 'Tracks purchased AI pack credits';



CREATE TABLE IF NOT EXISTS "public"."user_ai_daily_usage" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "usage_date" "date" DEFAULT CURRENT_DATE,
    "uses_today" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "source" "text",
    CONSTRAINT "user_ai_daily_usage_source_check" CHECK (("source" = ANY (ARRAY['daily_free'::"text", 'pack'::"text", 'premium'::"text"])))
);


ALTER TABLE "public"."user_ai_daily_usage" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_ai_daily_usage" IS 'Tracks daily free AI usage (3 per day)';



CREATE TABLE IF NOT EXISTS "public"."user_ai_pack_purchases" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pack_type" character varying(20) NOT NULL,
    "credits_purchased" integer NOT NULL,
    "price_paid" numeric(10,2),
    "purchase_date" timestamp with time zone DEFAULT "now"(),
    "platform" character varying(20)
);


ALTER TABLE "public"."user_ai_pack_purchases" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_ai_pack_purchases" IS 'Records all AI pack purchases';



CREATE TABLE IF NOT EXISTS "public"."user_premium_status" (
    "user_id" "uuid" NOT NULL,
    "is_premium" boolean DEFAULT false,
    "premium_since" timestamp with time zone,
    "premium_expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "monthly_ai_credits" integer DEFAULT 100,
    "ai_credits_refreshed_at" timestamp with time zone DEFAULT "now"(),
    "premium_source" "text"
);


ALTER TABLE "public"."user_premium_status" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_premium_status" IS 'Tracks user premium subscription status';



COMMENT ON COLUMN "public"."user_premium_status"."premium_source" IS 'Source of premium subscription: apple, google, stripe, or twitch. Used for hierarchy and conflict resolution.';



CREATE OR REPLACE VIEW "public"."user_ai_status" WITH ("security_invoker"='true') AS
 SELECT "uac"."user_id",
    COALESCE("uac"."pack_credits", 0) AS "pack_credits",
    COALESCE("ups"."is_premium", false) AS "is_premium",
    COALESCE("ups"."monthly_ai_credits", 0) AS "monthly_ai_credits",
    ( SELECT "count"(*) AS "count"
           FROM "public"."user_ai_daily_usage" "uadu"
          WHERE (("uadu"."user_id" = "uac"."user_id") AND (("uadu"."created_at")::"date" = CURRENT_DATE))) AS "daily_free_used"
   FROM ("public"."user_ai_credits" "uac"
     LEFT JOIN "public"."user_premium_status" "ups" ON (("ups"."user_id" = "uac"."user_id")));


ALTER VIEW "public"."user_ai_status" OWNER TO "postgres";


COMMENT ON VIEW "public"."user_ai_status" IS 'Secure view of user AI credit status without exposing auth.users data';



CREATE TABLE IF NOT EXISTS "public"."user_progress" (
    "user_id" "uuid" NOT NULL,
    "platform_id" bigint NOT NULL,
    "platform_game_id" "text" NOT NULL,
    "current_score" integer DEFAULT 0,
    "achievements_earned" integer DEFAULT 0,
    "total_achievements" integer DEFAULT 0,
    "completion_percentage" numeric(5,2) DEFAULT 0,
    "first_played_at" timestamp with time zone,
    "last_played_at" timestamp with time zone,
    "synced_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "last_achievement_earned_at" timestamp with time zone
);


ALTER TABLE "public"."user_progress" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_progress" IS 'User progress per platform-specific game. Composite PK prevents duplicates.';



COMMENT ON COLUMN "public"."user_progress"."current_score" IS 'Platform-native score per game. Xbox: currentGamerscore from API. PSN: trophy points if available. Steam: 0 (no score system). Do NOT store StatusXP here.';



CREATE OR REPLACE VIEW "public"."user_games" AS
 WITH "user_game_progress" AS (
         SELECT "up"."user_id",
            "up"."platform_id",
            "up"."platform_game_id",
            "up"."achievements_earned" AS "earned_trophies",
            "up"."total_achievements" AS "total_trophies",
            "up"."completion_percentage",
            "up"."current_score",
            "up"."last_played_at",
            ((('x'::"text" || "substr"("md5"(((("up"."platform_id")::"text" || '_'::"text") || "up"."platform_game_id")), 1, 15)))::bit(60))::bigint AS "game_title_id",
            "g"."name"
           FROM ("public"."user_progress" "up"
             JOIN "public"."games" "g" ON ((("g"."platform_id" = "up"."platform_id") AND ("g"."platform_game_id" = "up"."platform_game_id"))))
        ), "psn_trophy_breakdown" AS (
         SELECT "ua"."user_id",
            "ua"."platform_id",
            "ua"."platform_game_id",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'bronze'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "bronze_trophies",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'silver'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "silver_trophies",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'gold'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "gold_trophies",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'platinum'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "platinum_trophies",
            "max"("ua"."earned_at") AS "last_trophy_earned_at",
            (EXISTS ( SELECT 1
                   FROM "public"."achievements" "a2"
                  WHERE (("a2"."platform_id" = "ua"."platform_id") AND ("a2"."platform_game_id" = "ua"."platform_game_id") AND (("a2"."metadata" ->> 'psn_trophy_type'::"text") = 'platinum'::"text")))) AS "has_platinum"
           FROM ("public"."user_achievements" "ua"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ua"."platform_id") AND ("a"."platform_game_id" = "ua"."platform_game_id") AND ("a"."platform_achievement_id" = "ua"."platform_achievement_id"))))
          WHERE ("ua"."platform_id" = ANY (ARRAY[(1)::bigint, (2)::bigint, (5)::bigint, (9)::bigint]))
          GROUP BY "ua"."user_id", "ua"."platform_id", "ua"."platform_game_id"
        )
 SELECT "row_number"() OVER (ORDER BY "ugp"."user_id", "ugp"."platform_id", "ugp"."platform_game_id") AS "id",
    "ugp"."user_id",
    "ugp"."game_title_id",
    "ugp"."platform_id",
    "ugp"."name" AS "game_title",
    COALESCE("psn"."has_platinum", false) AS "has_platinum",
    COALESCE("psn"."bronze_trophies", (0)::bigint) AS "bronze_trophies",
    COALESCE("psn"."silver_trophies", (0)::bigint) AS "silver_trophies",
    COALESCE("psn"."gold_trophies", (0)::bigint) AS "gold_trophies",
    COALESCE("psn"."platinum_trophies", (0)::bigint) AS "platinum_trophies",
    COALESCE("psn"."last_trophy_earned_at", "ugp"."last_played_at") AS "last_trophy_earned_at",
    "ugp"."total_trophies",
    "ugp"."earned_trophies",
    "ugp"."completion_percentage" AS "completion_percent",
    "ugp"."last_played_at",
    "ugp"."current_score",
    "now"() AS "created_at",
    "now"() AS "updated_at"
   FROM ("user_game_progress" "ugp"
     LEFT JOIN "psn_trophy_breakdown" "psn" ON ((("psn"."user_id" = "ugp"."user_id") AND ("psn"."platform_id" = "ugp"."platform_id") AND ("psn"."platform_game_id" = "ugp"."platform_game_id"))));


ALTER VIEW "public"."user_games" OWNER TO "postgres";


COMMENT ON VIEW "public"."user_games" IS 'User games with trophy breakdown for all PlayStation platforms (PS5, PS4, PS3, PSVita). Fixed Jan 31, 2026 - was only calculating for PS5.';



CREATE TABLE IF NOT EXISTS "public"."user_meta_achievements" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "achievement_id" "text" NOT NULL,
    "custom_title" "text",
    "unlocked_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_meta_achievements" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."user_meta_achievements_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."user_meta_achievements_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."user_meta_achievements_id_seq" OWNED BY "public"."user_meta_achievements"."id";



CREATE TABLE IF NOT EXISTS "public"."user_profile_settings" (
    "user_id" "uuid" NOT NULL,
    "profile_theme_id" bigint,
    "is_profile_public" boolean DEFAULT true,
    "show_rarest_trophy" boolean DEFAULT true,
    "show_hardest_platinum" boolean DEFAULT true,
    "show_completed_games" boolean DEFAULT true,
    "time_zone" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_profile_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_selected_title" (
    "user_id" "uuid" NOT NULL,
    "achievement_id" "text",
    "custom_title" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_selected_title" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_stat_snapshots" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "total_statusxp" integer DEFAULT 0 NOT NULL,
    "platinum_count" integer DEFAULT 0 NOT NULL,
    "gamerscore" integer DEFAULT 0,
    "psn_gold_count" integer DEFAULT 0,
    "psn_silver_count" integer DEFAULT 0,
    "psn_bronze_count" integer DEFAULT 0,
    "steam_achievement_count" integer DEFAULT 0,
    "latest_game_title" "text",
    "latest_platform_id" integer,
    "synced_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_stat_snapshots" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_stat_snapshots" IS 'Captures user stats at each sync for before/after comparison';



CREATE SEQUENCE IF NOT EXISTS "public"."user_stat_snapshots_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."user_stat_snapshots_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."user_stat_snapshots_id_seq" OWNED BY "public"."user_stat_snapshots"."id";



CREATE TABLE IF NOT EXISTS "public"."user_stats" (
    "user_id" "uuid" NOT NULL,
    "total_games" integer DEFAULT 0,
    "completed_games" integer DEFAULT 0,
    "total_trophies" integer DEFAULT 0,
    "bronze_count" integer DEFAULT 0,
    "silver_count" integer DEFAULT 0,
    "gold_count" integer DEFAULT 0,
    "platinum_count" integer DEFAULT 0,
    "total_gamerscore" integer DEFAULT 0,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_stats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_sync_history" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "platform" character varying(20) NOT NULL,
    "synced_at" timestamp with time zone DEFAULT "now"(),
    "success" boolean DEFAULT true,
    "profile_id" "uuid"
);


ALTER TABLE "public"."user_sync_history" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_sync_history" IS 'Tracks sync operations for rate limiting';



CREATE OR REPLACE VIEW "public"."user_sync_status" WITH ("security_invoker"='true') AS
 SELECT "ush"."user_id",
    "ush"."platform",
    "count"(*) FILTER (WHERE (("ush"."synced_at")::"date" = CURRENT_DATE)) AS "syncs_today",
    "max"("ush"."synced_at") AS "last_sync_at",
    "ups"."is_premium"
   FROM ("public"."user_sync_history" "ush"
     LEFT JOIN "public"."user_premium_status" "ups" ON (("ups"."user_id" = "ush"."user_id")))
  WHERE ("ush"."success" = true)
  GROUP BY "ush"."user_id", "ush"."platform", "ups"."is_premium";


ALTER VIEW "public"."user_sync_status" OWNER TO "postgres";


COMMENT ON VIEW "public"."user_sync_status" IS 'Secure view of user sync status - uses security_invoker to enforce RLS';



CREATE OR REPLACE VIEW "public"."xbox_leaderboard_cache" AS
 WITH "xbox_user_stats" AS (
         SELECT "up"."user_id",
            "sum"("up"."current_score") AS "total_gamerscore",
            "count"(DISTINCT ROW("up"."platform_id", "up"."platform_game_id")) AS "total_games"
           FROM "public"."user_progress" "up"
          WHERE ("up"."platform_id" = ANY (ARRAY[(10)::bigint, (11)::bigint, (12)::bigint]))
          GROUP BY "up"."user_id"
        ), "xbox_potential" AS (
         SELECT "up"."user_id",
            "sum"("a"."score_value") AS "potential_gamerscore"
           FROM ("public"."user_progress" "up"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "up"."platform_id") AND ("a"."platform_game_id" = "up"."platform_game_id"))))
          WHERE ("up"."platform_id" = ANY (ARRAY[(10)::bigint, (11)::bigint, (12)::bigint]))
          GROUP BY "up"."user_id"
        ), "xbox_achievement_count" AS (
         SELECT "ua"."user_id",
            "count"(*) AS "achievement_count"
           FROM "public"."user_achievements" "ua"
          WHERE ("ua"."platform_id" = ANY (ARRAY[(10)::bigint, (11)::bigint, (12)::bigint]))
          GROUP BY "ua"."user_id"
        )
 SELECT "xus"."user_id",
    COALESCE("p"."xbox_gamertag", "p"."display_name", "p"."username", 'Player'::"text") AS "display_name",
    "p"."xbox_avatar_url" AS "avatar_url",
    COALESCE("xac"."achievement_count", (0)::bigint) AS "achievement_count",
    "xus"."total_games",
    COALESCE("xus"."total_gamerscore", (0)::bigint) AS "gamerscore",
    COALESCE("xp"."potential_gamerscore", (0)::bigint) AS "potential_gamerscore",
    "now"() AS "updated_at"
   FROM ((("xbox_user_stats" "xus"
     JOIN "public"."profiles" "p" ON (("p"."id" = "xus"."user_id")))
     LEFT JOIN "xbox_achievement_count" "xac" ON (("xac"."user_id" = "xus"."user_id")))
     LEFT JOIN "xbox_potential" "xp" ON (("xp"."user_id" = "xus"."user_id")))
  WHERE ("p"."show_on_leaderboard" = true)
  ORDER BY COALESCE("xus"."total_gamerscore", (0)::bigint) DESC, COALESCE("xac"."achievement_count", (0)::bigint) DESC, "xus"."total_games" DESC;


ALTER VIEW "public"."xbox_leaderboard_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."xbox_leaderboard_history" (
    "user_id" "uuid" NOT NULL,
    "snapshot_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rank" integer NOT NULL,
    "gamerscore" integer NOT NULL,
    "achievement_count" integer NOT NULL,
    "total_games" integer NOT NULL
);


ALTER TABLE "public"."xbox_leaderboard_history" OWNER TO "postgres";


COMMENT ON TABLE "public"."xbox_leaderboard_history" IS 'Historical snapshots of Xbox gamerscore leaderboard rankings for tracking movement over time';



CREATE TABLE IF NOT EXISTS "public"."xbox_sync_logs" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "sync_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "games_processed" integer DEFAULT 0,
    "achievements_synced" integer DEFAULT 0,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "games_processed_ids" "text"[] DEFAULT '{}'::"text"[],
    CONSTRAINT "xbox_sync_logs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'syncing'::"text", 'completed'::"text", 'failed'::"text"]))),
    CONSTRAINT "xbox_sync_logs_sync_type_check" CHECK (("sync_type" = ANY (ARRAY['full'::"text", 'incremental'::"text"])))
);


ALTER TABLE "public"."xbox_sync_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."xbox_sync_logs" IS 'Optimized: auth.uid() wrapped in subquery, single policy per operation';



CREATE SEQUENCE IF NOT EXISTS "public"."xbox_sync_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."xbox_sync_logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."xbox_sync_logs_id_seq" OWNED BY "public"."xbox_sync_logs"."id";



ALTER TABLE ONLY "public"."activity_feed" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."activity_feed_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."game_groups" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."game_groups_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."game_groups_refresh_queue" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."game_groups_refresh_queue_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."platforms" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."platforms_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."profile_themes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."profile_themes_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."psn_sync_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."psn_sync_logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."steam_sync_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."steam_sync_logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."trophy_room_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."trophy_room_items_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."trophy_room_shelves" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."trophy_room_shelves_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."user_meta_achievements" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."user_meta_achievements_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."user_stat_snapshots" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."user_stat_snapshots_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."xbox_sync_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."xbox_sync_logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."achievement_comments"
    ADD CONSTRAINT "achievement_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_pkey" PRIMARY KEY ("platform_id", "platform_game_id", "platform_achievement_id");



ALTER TABLE ONLY "public"."activity_feed"
    ADD CONSTRAINT "activity_feed_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."activity_feed_views"
    ADD CONSTRAINT "activity_feed_views_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."app_updates"
    ADD CONSTRAINT "app_updates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."flex_room_data"
    ADD CONSTRAINT "flex_room_data_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."game_groups"
    ADD CONSTRAINT "game_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."game_groups_refresh_queue"
    ADD CONSTRAINT "game_groups_refresh_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."games"
    ADD CONSTRAINT "games_pkey" PRIMARY KEY ("platform_id", "platform_game_id");



ALTER TABLE ONLY "public"."leaderboard_cache"
    ADD CONSTRAINT "leaderboard_cache_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."leaderboard_history"
    ADD CONSTRAINT "leaderboard_history_pkey" PRIMARY KEY ("user_id", "snapshot_at");



ALTER TABLE ONLY "public"."meta_achievements"
    ADD CONSTRAINT "meta_achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platforms"
    ADD CONSTRAINT "platforms_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."platforms"
    ADD CONSTRAINT "platforms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_themes"
    ADD CONSTRAINT "profile_themes_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."profile_themes"
    ADD CONSTRAINT "profile_themes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."psn_leaderboard_history"
    ADD CONSTRAINT "psn_leaderboard_history_pkey" PRIMARY KEY ("user_id", "snapshot_at");



ALTER TABLE ONLY "public"."psn_sync_logs"
    ADD CONSTRAINT "psn_sync_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."psn_user_trophy_profile"
    ADD CONSTRAINT "psn_user_trophy_profile_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."steam_leaderboard_history"
    ADD CONSTRAINT "steam_leaderboard_history_pkey" PRIMARY KEY ("user_id", "snapshot_at");



ALTER TABLE ONLY "public"."steam_sync_logs"
    ADD CONSTRAINT "steam_sync_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trophy_help_requests"
    ADD CONSTRAINT "trophy_help_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trophy_help_responses"
    ADD CONSTRAINT "trophy_help_responses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trophy_room_items"
    ADD CONSTRAINT "trophy_room_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trophy_room_items"
    ADD CONSTRAINT "trophy_room_items_shelf_id_slot_index_key" UNIQUE ("shelf_id", "slot_index");



ALTER TABLE ONLY "public"."trophy_room_shelves"
    ADD CONSTRAINT "trophy_room_shelves_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_stat_snapshots"
    ADD CONSTRAINT "unique_user_sync" UNIQUE ("user_id", "synced_at");



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_pkey" PRIMARY KEY ("user_id", "platform_id", "platform_game_id", "platform_achievement_id");



ALTER TABLE ONLY "public"."user_ai_credits"
    ADD CONSTRAINT "user_ai_credits_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_ai_daily_usage"
    ADD CONSTRAINT "user_ai_daily_usage_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_ai_daily_usage"
    ADD CONSTRAINT "user_ai_daily_usage_user_id_usage_date_key" UNIQUE ("user_id", "usage_date");



ALTER TABLE ONLY "public"."user_ai_pack_purchases"
    ADD CONSTRAINT "user_ai_pack_purchases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_meta_achievements"
    ADD CONSTRAINT "user_meta_achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_meta_achievements"
    ADD CONSTRAINT "user_meta_achievements_user_id_achievement_id_key" UNIQUE ("user_id", "achievement_id");



ALTER TABLE ONLY "public"."user_premium_status"
    ADD CONSTRAINT "user_premium_status_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_profile_settings"
    ADD CONSTRAINT "user_profile_settings_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_progress"
    ADD CONSTRAINT "user_progress_pkey" PRIMARY KEY ("user_id", "platform_id", "platform_game_id");



ALTER TABLE ONLY "public"."user_selected_title"
    ADD CONSTRAINT "user_selected_title_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_stat_snapshots"
    ADD CONSTRAINT "user_stat_snapshots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_stats"
    ADD CONSTRAINT "user_stats_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_sync_history"
    ADD CONSTRAINT "user_sync_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."xbox_leaderboard_history"
    ADD CONSTRAINT "xbox_leaderboard_history_pkey" PRIMARY KEY ("user_id", "snapshot_at");



ALTER TABLE ONLY "public"."xbox_sync_logs"
    ADD CONSTRAINT "xbox_sync_logs_pkey" PRIMARY KEY ("id");



CREATE INDEX "app_updates_release_date_idx" ON "public"."app_updates" USING "btree" ("release_date" DESC);



CREATE INDEX "idx_achievement_comments_achievement_composite" ON "public"."achievement_comments" USING "btree" ("platform_id", "platform_game_id", "platform_achievement_id");



CREATE INDEX "idx_achievement_comments_created_at" ON "public"."achievement_comments" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_achievement_comments_user_id" ON "public"."achievement_comments" USING "btree" ("user_id");



CREATE INDEX "idx_achievements_game" ON "public"."achievements" USING "btree" ("platform_id", "platform_game_id");



CREATE INDEX "idx_achievements_rarity" ON "public"."achievements" USING "btree" ("rarity_global") WHERE ("rarity_global" IS NOT NULL);



CREATE INDEX "idx_achievements_statusxp" ON "public"."achievements" USING "btree" ("base_status_xp_old", "rarity_multiplier");



CREATE INDEX "idx_activity_feed_created" ON "public"."activity_feed" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_activity_feed_date" ON "public"."activity_feed" USING "btree" ("event_date" DESC) WHERE ("is_visible" = true);



CREATE INDEX "idx_activity_feed_expires" ON "public"."activity_feed" USING "btree" ("expires_at");



CREATE INDEX "idx_activity_feed_type" ON "public"."activity_feed" USING "btree" ("event_type");



CREATE INDEX "idx_activity_feed_user" ON "public"."activity_feed" USING "btree" ("user_id");



CREATE INDEX "idx_activity_views_time" ON "public"."activity_feed_views" USING "btree" ("last_viewed_at");



CREATE UNIQUE INDEX "idx_flex_room_data_profile_id" ON "public"."flex_room_data" USING "btree" ("profile_id");



CREATE INDEX "idx_game_groups_game_title_ids" ON "public"."game_groups" USING "gin" ("game_title_ids");



CREATE INDEX "idx_game_groups_primary_game_id" ON "public"."game_groups" USING "btree" ("primary_game_id");



CREATE INDEX "idx_games_name" ON "public"."games" USING "btree" ("name");



CREATE INDEX "idx_games_name_lower" ON "public"."games" USING "btree" ("lower"(TRIM(BOTH FROM "name")));



CREATE INDEX "idx_games_platform_id" ON "public"."games" USING "btree" ("platform_id");



CREATE INDEX "idx_leaderboard_cache_statusxp" ON "public"."leaderboard_cache" USING "btree" ("total_statusxp" DESC);



CREATE INDEX "idx_leaderboard_history_snapshot_at" ON "public"."leaderboard_history" USING "btree" ("snapshot_at" DESC);



CREATE INDEX "idx_leaderboard_history_user_snapshot" ON "public"."leaderboard_history" USING "btree" ("user_id", "snapshot_at" DESC);



CREATE INDEX "idx_meta_achievements_category" ON "public"."meta_achievements" USING "btree" ("category");



CREATE INDEX "idx_platforms_code" ON "public"."platforms" USING "btree" ("code");



CREATE INDEX "idx_profile_themes_code" ON "public"."profile_themes" USING "btree" ("code");



CREATE INDEX "idx_profiles_last_xbox_sync" ON "public"."profiles" USING "btree" ("last_xbox_sync_at" DESC) WHERE ("last_xbox_sync_at" IS NOT NULL);



CREATE INDEX "idx_profiles_leaderboard" ON "public"."profiles" USING "btree" ("show_on_leaderboard") WHERE ("show_on_leaderboard" = true);



CREATE INDEX "idx_profiles_merged_into" ON "public"."profiles" USING "btree" ("merged_into_user_id") WHERE ("merged_into_user_id" IS NOT NULL);



CREATE INDEX "idx_profiles_psn" ON "public"."profiles" USING "btree" ("psn_online_id") WHERE ("psn_online_id" IS NOT NULL);



CREATE INDEX "idx_profiles_psn_account_id" ON "public"."profiles" USING "btree" ("psn_account_id") WHERE ("psn_account_id" IS NOT NULL);



CREATE INDEX "idx_profiles_psn_is_plus" ON "public"."profiles" USING "btree" ("psn_is_plus") WHERE ("psn_is_plus" = true);



CREATE INDEX "idx_profiles_psn_sync_status" ON "public"."profiles" USING "btree" ("psn_sync_status");



CREATE INDEX "idx_profiles_show_on_leaderboard" ON "public"."profiles" USING "btree" ("show_on_leaderboard");



CREATE INDEX "idx_profiles_steam" ON "public"."profiles" USING "btree" ("steam_id") WHERE ("steam_id" IS NOT NULL);



CREATE INDEX "idx_profiles_steam_sync_status" ON "public"."profiles" USING "btree" ("steam_sync_status");



CREATE INDEX "idx_profiles_subscription_tier" ON "public"."profiles" USING "btree" ("subscription_tier");



CREATE INDEX "idx_profiles_twitch_user_id" ON "public"."profiles" USING "btree" ("twitch_user_id") WHERE ("twitch_user_id" IS NOT NULL);



CREATE INDEX "idx_profiles_username" ON "public"."profiles" USING "btree" ("username");



CREATE INDEX "idx_profiles_xbox" ON "public"."profiles" USING "btree" ("xbox_gamertag") WHERE ("xbox_gamertag" IS NOT NULL);



COMMENT ON INDEX "public"."idx_profiles_xbox" IS 'Index for Xbox gamertag lookups';



CREATE INDEX "idx_profiles_xbox_sync_status" ON "public"."profiles" USING "btree" ("xbox_sync_status");



CREATE INDEX "idx_profiles_xbox_xuid" ON "public"."profiles" USING "btree" ("xbox_xuid") WHERE ("xbox_xuid" IS NOT NULL);



CREATE INDEX "idx_psn_leaderboard_cache_platinum" ON "public"."psn_leaderboard_cache" USING "btree" ("platinum_count" DESC, "gold_count" DESC, "silver_count" DESC);



CREATE UNIQUE INDEX "idx_psn_leaderboard_cache_user_id" ON "public"."psn_leaderboard_cache" USING "btree" ("user_id");



CREATE INDEX "idx_psn_leaderboard_history_snapshot" ON "public"."psn_leaderboard_history" USING "btree" ("snapshot_at" DESC);



CREATE INDEX "idx_psn_leaderboard_history_user" ON "public"."psn_leaderboard_history" USING "btree" ("user_id", "snapshot_at" DESC);



CREATE INDEX "idx_psn_sync_logs_started_at" ON "public"."psn_sync_logs" USING "btree" ("started_at" DESC);



CREATE INDEX "idx_psn_sync_logs_status" ON "public"."psn_sync_logs" USING "btree" ("status");



CREATE INDEX "idx_psn_sync_logs_user_id" ON "public"."psn_sync_logs" USING "btree" ("user_id");



CREATE INDEX "idx_snapshots_cleanup" ON "public"."user_stat_snapshots" USING "btree" ("synced_at");



CREATE INDEX "idx_snapshots_user_time" ON "public"."user_stat_snapshots" USING "btree" ("user_id", "synced_at" DESC);



CREATE INDEX "idx_steam_leaderboard_history_snapshot" ON "public"."steam_leaderboard_history" USING "btree" ("snapshot_at" DESC);



CREATE INDEX "idx_steam_leaderboard_history_user" ON "public"."steam_leaderboard_history" USING "btree" ("user_id", "snapshot_at" DESC);



CREATE INDEX "idx_steam_sync_logs_started_at" ON "public"."steam_sync_logs" USING "btree" ("started_at" DESC);



CREATE INDEX "idx_steam_sync_logs_status" ON "public"."steam_sync_logs" USING "btree" ("status");



CREATE INDEX "idx_steam_sync_logs_user_id" ON "public"."steam_sync_logs" USING "btree" ("user_id");



CREATE INDEX "idx_sync_history_user_platform_date" ON "public"."user_sync_history" USING "btree" ("user_id", "platform", "synced_at" DESC);



COMMENT ON INDEX "public"."idx_sync_history_user_platform_date" IS 'Index for sync history queries by user, platform, and date';



CREATE INDEX "idx_trophy_help_requests_active_status" ON "public"."trophy_help_requests" USING "btree" ("status", "created_at" DESC) WHERE ("status" = ANY (ARRAY['open'::"text", 'assigned'::"text"]));



CREATE INDEX "idx_trophy_help_requests_created_at" ON "public"."trophy_help_requests" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_trophy_help_requests_game_id" ON "public"."trophy_help_requests" USING "btree" ("game_id");



CREATE INDEX "idx_trophy_help_requests_platform" ON "public"."trophy_help_requests" USING "btree" ("platform");



CREATE INDEX "idx_trophy_help_requests_profile_status" ON "public"."trophy_help_requests" USING "btree" ("profile_id", "status", "created_at" DESC);



CREATE INDEX "idx_trophy_help_requests_status" ON "public"."trophy_help_requests" USING "btree" ("status");



CREATE INDEX "idx_trophy_help_requests_user_id" ON "public"."trophy_help_requests" USING "btree" ("user_id");



CREATE INDEX "idx_trophy_help_responses_helper_profile" ON "public"."trophy_help_responses" USING "btree" ("helper_profile_id", "created_at" DESC);



CREATE INDEX "idx_trophy_help_responses_helper_user_id" ON "public"."trophy_help_responses" USING "btree" ("helper_user_id");



CREATE INDEX "idx_trophy_help_responses_pending" ON "public"."trophy_help_responses" USING "btree" ("status", "created_at" DESC) WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_trophy_help_responses_request_id" ON "public"."trophy_help_responses" USING "btree" ("request_id");



CREATE INDEX "idx_trophy_room_items_game" ON "public"."trophy_room_items" USING "btree" ("game_title_id") WHERE ("game_title_id" IS NOT NULL);



CREATE INDEX "idx_trophy_room_items_shelf" ON "public"."trophy_room_items" USING "btree" ("shelf_id", "slot_index");



CREATE INDEX "idx_trophy_room_items_trophy" ON "public"."trophy_room_items" USING "btree" ("trophy_id") WHERE ("trophy_id" IS NOT NULL);



CREATE INDEX "idx_trophy_room_shelves_user" ON "public"."trophy_room_shelves" USING "btree" ("user_id", "sort_order");



CREATE INDEX "idx_user_achievements_achievement" ON "public"."user_achievements" USING "btree" ("platform_id", "platform_game_id", "platform_achievement_id");



CREATE INDEX "idx_user_achievements_earned_at" ON "public"."user_achievements" USING "btree" ("earned_at" DESC);



CREATE INDEX "idx_user_achievements_user" ON "public"."user_achievements" USING "btree" ("user_id");



CREATE INDEX "idx_user_achievements_v2_earned" ON "public"."user_achievements" USING "btree" ("earned_at");



CREATE INDEX "idx_user_ai_credits_user_id" ON "public"."user_ai_credits" USING "btree" ("user_id");



CREATE INDEX "idx_user_ai_daily_usage_user_date" ON "public"."user_ai_daily_usage" USING "btree" ("user_id", "usage_date");



CREATE INDEX "idx_user_ai_pack_purchases_user_id" ON "public"."user_ai_pack_purchases" USING "btree" ("user_id");



CREATE INDEX "idx_user_meta_achievements_achievement_id" ON "public"."user_meta_achievements" USING "btree" ("achievement_id");



CREATE INDEX "idx_user_meta_achievements_user_id" ON "public"."user_meta_achievements" USING "btree" ("user_id");



CREATE INDEX "idx_user_premium_status_source" ON "public"."user_premium_status" USING "btree" ("premium_source") WHERE ("premium_source" IS NOT NULL);



CREATE INDEX "idx_user_premium_status_user_id" ON "public"."user_premium_status" USING "btree" ("user_id");



CREATE INDEX "idx_user_progress_completion" ON "public"."user_progress" USING "btree" ("completion_percentage" DESC) WHERE ("completion_percentage" = (100)::numeric);



CREATE INDEX "idx_user_progress_game" ON "public"."user_progress" USING "btree" ("platform_id", "platform_game_id");



CREATE INDEX "idx_user_progress_user" ON "public"."user_progress" USING "btree" ("user_id");



CREATE INDEX "idx_user_progress_v2_platform" ON "public"."user_progress" USING "btree" ("platform_id");



CREATE INDEX "idx_user_progress_v2_score" ON "public"."user_progress" USING "btree" ("user_id", "current_score") WHERE ("current_score" > 0);



CREATE INDEX "idx_xbox_leaderboard_history_snapshot" ON "public"."xbox_leaderboard_history" USING "btree" ("snapshot_at" DESC);



CREATE INDEX "idx_xbox_leaderboard_history_user" ON "public"."xbox_leaderboard_history" USING "btree" ("user_id", "snapshot_at" DESC);



CREATE INDEX "idx_xbox_sync_logs_started_at" ON "public"."xbox_sync_logs" USING "btree" ("started_at" DESC);



CREATE INDEX "idx_xbox_sync_logs_status" ON "public"."xbox_sync_logs" USING "btree" ("status");



CREATE INDEX "idx_xbox_sync_logs_user_id" ON "public"."xbox_sync_logs" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "auto_calculate_statusxp" BEFORE INSERT OR UPDATE ON "public"."achievements" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_achievement_statusxp"();



CREATE OR REPLACE TRIGGER "set_last_updated" BEFORE UPDATE ON "public"."flex_room_data" FOR EACH ROW EXECUTE FUNCTION "public"."update_flex_room_last_updated"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."achievement_comments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_leaderboard_on_achievements" AFTER INSERT OR DELETE OR UPDATE ON "public"."user_achievements" FOR EACH ROW EXECUTE FUNCTION "public"."update_leaderboard_on_achievements_change"();



CREATE OR REPLACE TRIGGER "update_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_trophy_help_request_updated_at_trigger" BEFORE UPDATE ON "public"."trophy_help_requests" FOR EACH ROW EXECUTE FUNCTION "public"."update_trophy_help_request_updated_at"();



CREATE OR REPLACE TRIGGER "update_trophy_room_items_updated_at" BEFORE UPDATE ON "public"."trophy_room_items" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_trophy_room_shelves_updated_at" BEFORE UPDATE ON "public"."trophy_room_shelves" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_user_profile_settings_updated_at" BEFORE UPDATE ON "public"."user_profile_settings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."achievement_comments"
    ADD CONSTRAINT "achievement_comments_achievement_fkey" FOREIGN KEY ("platform_id", "platform_game_id", "platform_achievement_id") REFERENCES "public"."achievements"("platform_id", "platform_game_id", "platform_achievement_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."achievement_comments"
    ADD CONSTRAINT "achievement_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_platform_id_platform_game_id_fkey" FOREIGN KEY ("platform_id", "platform_game_id") REFERENCES "public"."games"("platform_id", "platform_game_id");



ALTER TABLE ONLY "public"."activity_feed"
    ADD CONSTRAINT "activity_feed_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."activity_feed_views"
    ADD CONSTRAINT "activity_feed_views_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."flex_room_data"
    ADD CONSTRAINT "fk_flex_of_all_time" FOREIGN KEY ("flex_of_all_time_platform_id", "flex_of_all_time_platform_game_id", "flex_of_all_time_platform_achievement_id") REFERENCES "public"."achievements"("platform_id", "platform_game_id", "platform_achievement_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."flex_room_data"
    ADD CONSTRAINT "fk_most_time_sunk" FOREIGN KEY ("most_time_sunk_platform_id", "most_time_sunk_platform_game_id", "most_time_sunk_platform_achievement_id") REFERENCES "public"."achievements"("platform_id", "platform_game_id", "platform_achievement_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."flex_room_data"
    ADD CONSTRAINT "fk_rarest_flex" FOREIGN KEY ("rarest_flex_platform_id", "rarest_flex_platform_game_id", "rarest_flex_platform_achievement_id") REFERENCES "public"."achievements"("platform_id", "platform_game_id", "platform_achievement_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."flex_room_data"
    ADD CONSTRAINT "fk_sweatiest_platinum" FOREIGN KEY ("sweatiest_platinum_platform_id", "sweatiest_platinum_platform_game_id", "sweatiest_platinum_platform_achievement_id") REFERENCES "public"."achievements"("platform_id", "platform_game_id", "platform_achievement_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."flex_room_data"
    ADD CONSTRAINT "flex_room_data_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."games"
    ADD CONSTRAINT "games_platform_id_fkey" FOREIGN KEY ("platform_id") REFERENCES "public"."platforms"("id");



ALTER TABLE ONLY "public"."leaderboard_cache"
    ADD CONSTRAINT "leaderboard_cache_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_merged_into_user_id_fkey" FOREIGN KEY ("merged_into_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."psn_sync_logs"
    ADD CONSTRAINT "psn_sync_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."psn_user_trophy_profile"
    ADD CONSTRAINT "psn_user_trophy_profile_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."steam_sync_logs"
    ADD CONSTRAINT "steam_sync_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trophy_help_requests"
    ADD CONSTRAINT "trophy_help_requests_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trophy_help_responses"
    ADD CONSTRAINT "trophy_help_responses_helper_profile_id_fkey" FOREIGN KEY ("helper_profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trophy_help_responses"
    ADD CONSTRAINT "trophy_help_responses_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "public"."trophy_help_requests"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trophy_room_items"
    ADD CONSTRAINT "trophy_room_items_shelf_id_fkey" FOREIGN KEY ("shelf_id") REFERENCES "public"."trophy_room_shelves"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trophy_room_shelves"
    ADD CONSTRAINT "trophy_room_shelves_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_v2_platform_id_platform_game_id_platform_fkey" FOREIGN KEY ("platform_id", "platform_game_id", "platform_achievement_id") REFERENCES "public"."achievements"("platform_id", "platform_game_id", "platform_achievement_id");



ALTER TABLE ONLY "public"."user_ai_credits"
    ADD CONSTRAINT "user_ai_credits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_ai_daily_usage"
    ADD CONSTRAINT "user_ai_daily_usage_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_ai_pack_purchases"
    ADD CONSTRAINT "user_ai_pack_purchases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_meta_achievements"
    ADD CONSTRAINT "user_meta_achievements_achievement_id_fkey" FOREIGN KEY ("achievement_id") REFERENCES "public"."meta_achievements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_meta_achievements"
    ADD CONSTRAINT "user_meta_achievements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_premium_status"
    ADD CONSTRAINT "user_premium_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_profile_settings"
    ADD CONSTRAINT "user_profile_settings_profile_theme_id_fkey" FOREIGN KEY ("profile_theme_id") REFERENCES "public"."profile_themes"("id");



ALTER TABLE ONLY "public"."user_profile_settings"
    ADD CONSTRAINT "user_profile_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_progress"
    ADD CONSTRAINT "user_progress_platform_id_platform_game_id_fkey" FOREIGN KEY ("platform_id", "platform_game_id") REFERENCES "public"."games"("platform_id", "platform_game_id");



ALTER TABLE ONLY "public"."user_progress"
    ADD CONSTRAINT "user_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_selected_title"
    ADD CONSTRAINT "user_selected_title_achievement_id_fkey" FOREIGN KEY ("achievement_id") REFERENCES "public"."meta_achievements"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_selected_title"
    ADD CONSTRAINT "user_selected_title_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_stat_snapshots"
    ADD CONSTRAINT "user_stat_snapshots_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_stats"
    ADD CONSTRAINT "user_stats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_sync_history"
    ADD CONSTRAINT "user_sync_history_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_sync_history"
    ADD CONSTRAINT "user_sync_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."xbox_sync_logs"
    ADD CONSTRAINT "xbox_sync_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Anyone can read achievements" ON "public"."achievements" FOR SELECT TO "anon", "authenticated" USING (true);



CREATE POLICY "Anyone can read game groups" ON "public"."game_groups" FOR SELECT TO "anon", "authenticated" USING (true);



CREATE POLICY "Anyone can read games" ON "public"."games" FOR SELECT TO "anon", "authenticated" USING (true);



CREATE POLICY "Anyone can read leaderboard cache" ON "public"."leaderboard_cache" FOR SELECT TO "anon", "authenticated" USING (true);



CREATE POLICY "Anyone can view achievements for leaderboard users" ON "public"."user_achievements" FOR SELECT TO "anon", "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "user_achievements"."user_id") AND ("p"."show_on_leaderboard" = true)))));



CREATE POLICY "Anyone can view app updates" ON "public"."app_updates" FOR SELECT USING (true);



CREATE POLICY "Anyone can view meta achievements" ON "public"."meta_achievements" FOR SELECT USING (true);



CREATE POLICY "Anyone can view non-hidden comments" ON "public"."achievement_comments" FOR SELECT USING (("is_hidden" = false));



CREATE POLICY "Anyone can view open trophy help requests" ON "public"."trophy_help_requests" FOR SELECT USING ((("status" = 'open'::"text") OR ("auth"."uid"() = "profile_id")));



CREATE POLICY "Anyone can view progress for leaderboard users" ON "public"."user_progress" FOR SELECT TO "anon", "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "user_progress"."user_id") AND ("p"."show_on_leaderboard" = true)))));



CREATE POLICY "Authenticated users can insert comments" ON "public"."achievement_comments" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Public read access" ON "public"."platforms" FOR SELECT USING (true);



CREATE POLICY "Public read access" ON "public"."profile_themes" FOR SELECT USING (true);



CREATE POLICY "Request owners can update response status" ON "public"."trophy_help_responses" FOR UPDATE USING (("auth"."uid"() IN ( SELECT "r"."profile_id"
   FROM "public"."trophy_help_requests" "r"
  WHERE ("r"."id" = "trophy_help_responses"."request_id"))));



CREATE POLICY "Service role can delete achievements" ON "public"."user_achievements" FOR DELETE TO "service_role" USING (true);



CREATE POLICY "Service role can delete progress" ON "public"."user_progress" FOR DELETE TO "service_role" USING (true);



CREATE POLICY "Service role can insert achievements" ON "public"."user_achievements" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Service role can insert progress" ON "public"."user_progress" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Service role can manage app updates" ON "public"."app_updates" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can manage refresh queue" ON "public"."game_groups_refresh_queue" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Service role can update achievements" ON "public"."user_achievements" FOR UPDATE TO "service_role" USING (true);



CREATE POLICY "Service role can update progress" ON "public"."user_progress" FOR UPDATE TO "service_role" USING (true);



CREATE POLICY "Users can create trophy help requests" ON "public"."trophy_help_requests" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Users can create trophy help responses" ON "public"."trophy_help_responses" FOR INSERT WITH CHECK (("auth"."uid"() = "helper_profile_id"));



CREATE POLICY "Users can delete own comments" ON "public"."achievement_comments" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own comments or admin can delete any" ON "public"."achievement_comments" FOR DELETE TO "authenticated" USING ((("auth"."uid"() = "user_id") OR ("auth"."uid"() = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::"uuid")));



CREATE POLICY "Users can delete their own flex room data" ON "public"."flex_room_data" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Users can delete their own trophy help requests" ON "public"."trophy_help_requests" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Users can insert own PSN sync logs" ON "public"."psn_sync_logs" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert own Steam sync logs" ON "public"."steam_sync_logs" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert own Xbox sync logs" ON "public"."xbox_sync_logs" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own AI credits" ON "public"."user_ai_credits" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own AI usage" ON "public"."user_ai_daily_usage" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own PSN trophy profile" ON "public"."psn_user_trophy_profile" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own flex room data" ON "public"."flex_room_data" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Users can insert their own premium status" ON "public"."user_premium_status" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own purchases" ON "public"."user_ai_pack_purchases" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own sync history" ON "public"."user_sync_history" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can post their own comments" ON "public"."achievement_comments" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can unlock their own meta achievements" ON "public"."user_meta_achievements" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update own PSN sync logs" ON "public"."psn_sync_logs" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update own Steam sync logs" ON "public"."steam_sync_logs" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update own Xbox sync logs" ON "public"."xbox_sync_logs" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update own comments" ON "public"."achievement_comments" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own AI credits" ON "public"."user_ai_credits" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own PSN trophy profile" ON "public"."psn_user_trophy_profile" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own flex room data" ON "public"."flex_room_data" FOR UPDATE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Users can update their own meta achievements" ON "public"."user_meta_achievements" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own premium status" ON "public"."user_premium_status" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own trophy help requests" ON "public"."trophy_help_requests" FOR UPDATE USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Users can view own PSN sync logs" ON "public"."psn_sync_logs" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view own Steam sync logs" ON "public"."steam_sync_logs" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view own Xbox sync logs" ON "public"."xbox_sync_logs" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view responses for their requests or their own respon" ON "public"."trophy_help_responses" FOR SELECT USING ((("auth"."uid"() = "helper_profile_id") OR ("auth"."uid"() IN ( SELECT "r"."profile_id"
   FROM "public"."trophy_help_requests" "r"
  WHERE ("r"."id" = "trophy_help_responses"."request_id")))));



CREATE POLICY "Users can view their own AI credits" ON "public"."user_ai_credits" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own AI usage" ON "public"."user_ai_daily_usage" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own PSN trophy profile" ON "public"."psn_user_trophy_profile" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own achievements" ON "public"."user_achievements" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own flex room data" ON "public"."flex_room_data" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Users can view their own meta achievements" ON "public"."user_meta_achievements" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own premium status" ON "public"."user_premium_status" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own progress" ON "public"."user_progress" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own purchase history" ON "public"."user_ai_pack_purchases" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own sync history" ON "public"."user_sync_history" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."achievement_comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_updates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."flex_room_data" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."game_groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."game_groups_refresh_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."games" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."leaderboard_cache" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meta_achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."platforms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_themes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_delete_policy" ON "public"."profiles" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "profiles_modify_policy" ON "public"."profiles" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "profiles_select_policy" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "profiles_update_policy" ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



ALTER TABLE "public"."psn_sync_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."psn_user_trophy_profile" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."steam_sync_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trophy_help_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trophy_help_responses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trophy_room_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trophy_room_items_policy" ON "public"."trophy_room_items" USING ((EXISTS ( SELECT 1
   FROM "public"."trophy_room_shelves"
  WHERE (("trophy_room_shelves"."id" = "trophy_room_items"."shelf_id") AND ("trophy_room_shelves"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



ALTER TABLE "public"."trophy_room_shelves" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trophy_room_shelves_policy" ON "public"."trophy_room_shelves" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."user_achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_ai_credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_ai_daily_usage" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_ai_pack_purchases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_meta_achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_premium_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_profile_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_profile_settings_policy" ON "public"."user_profile_settings" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."user_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_selected_title" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_selected_title_policy" ON "public"."user_selected_title" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."user_stats" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_stats_modify_delete" ON "public"."user_stats" FOR DELETE USING ((CURRENT_USER = 'service_role'::"name"));



CREATE POLICY "user_stats_modify_insert" ON "public"."user_stats" FOR INSERT WITH CHECK ((CURRENT_USER = 'service_role'::"name"));



CREATE POLICY "user_stats_modify_update" ON "public"."user_stats" FOR UPDATE USING ((CURRENT_USER = 'service_role'::"name"));



CREATE POLICY "user_stats_public_read" ON "public"."user_stats" FOR SELECT USING (true);



CREATE POLICY "user_stats_select_policy" ON "public"."user_stats" FOR SELECT USING (((CURRENT_USER = 'service_role'::"name") OR (( SELECT "auth"."uid"() AS "uid") = "user_id")));



ALTER TABLE "public"."user_sync_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."xbox_sync_logs" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."add_ai_credits"("p_user_id" "uuid", "p_credits" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_ai_credits"("p_user_id" "uuid", "p_credits" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_ai_credits"("p_user_id" "uuid", "p_credits" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."add_ai_pack_credits"("p_user_id" "uuid", "p_pack_type" character varying, "p_credits" integer, "p_price" numeric, "p_platform" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."add_ai_pack_credits"("p_user_id" "uuid", "p_pack_type" character varying, "p_credits" integer, "p_price" numeric, "p_platform" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_ai_pack_credits"("p_user_id" "uuid", "p_pack_type" character varying, "p_credits" integer, "p_price" numeric, "p_platform" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_refresh_all_leaderboards"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_refresh_all_leaderboards"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_refresh_all_leaderboards"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_achievement_similarity"("game_id_1" bigint, "game_id_2" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_achievement_similarity"("game_id_1" bigint, "game_id_2" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_achievement_similarity"("game_id_1" bigint, "game_id_2" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_achievement_statusxp"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_achievement_statusxp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_achievement_statusxp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_statusxp_simple"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_statusxp_simple"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_statusxp_simple"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_statusxp_with_stacks"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_statusxp_with_stacks"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_statusxp_with_stacks"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_user_achievement_statusxp"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_user_achievement_statusxp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_user_achievement_statusxp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_user_game_statusxp"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_user_game_statusxp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_user_game_statusxp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."can_use_ai"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_use_ai"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_use_ai"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_user_sync"("p_user_id" "uuid", "p_platform" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."can_user_sync"("p_user_id" "uuid", "p_platform" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_user_sync"("p_user_id" "uuid", "p_platform" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_user_sync_psn"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_user_sync_psn"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_user_sync_psn"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_big_comeback"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_big_comeback"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_big_comeback"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_closer"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_closer"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_closer"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_game_hopper"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_game_hopper"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_game_hopper"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_genre_diversity"("p_user_id" "uuid", "p_required_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."check_genre_diversity"("p_user_id" "uuid", "p_required_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_genre_diversity"("p_user_id" "uuid", "p_required_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."check_glow_up"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_glow_up"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_glow_up"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_power_session"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_power_session"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_power_session"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_spike_week"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_spike_week"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_spike_week"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_old_activity_feed"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_old_activity_feed"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_old_activity_feed"() TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_old_snapshots"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_old_snapshots"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_old_snapshots"() TO "service_role";



GRANT ALL ON FUNCTION "public"."consume_ai_credit"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."consume_ai_credit"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."consume_ai_credit"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_activity_feed_grouped"("p_user_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_activity_feed_grouped"("p_user_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_activity_feed_grouped"("p_user_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_games_with_platforms"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_games_with_platforms"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_games_with_platforms"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_grouped_games"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_grouped_games"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_grouped_games"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_grouped_games_fast"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_grouped_games_fast"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_grouped_games_fast"("search_query" "text", "platform_filter" "text", "result_limit" integer, "result_offset" integer, "sort_by" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_most_time_sunk_game"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_most_time_sunk_game"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_most_time_sunk_game"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_most_time_sunk_game_v2"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_most_time_sunk_game_v2"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_most_time_sunk_game_v2"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_platform_achievement_counts"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_platform_achievement_counts"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_platform_achievement_counts"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_platinum_leaderboard"("limit_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_platinum_leaderboard"("limit_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_platinum_leaderboard"("limit_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_psn_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_psn_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_psn_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_rarest_achievement_v2"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_rarest_achievement_v2"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_rarest_achievement_v2"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_recent_notable_achievements_v2"("p_user_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_recent_notable_achievements_v2"("p_user_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_recent_notable_achievements_v2"("p_user_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_steam_leaderboard"("limit_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_steam_leaderboard"("limit_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_steam_leaderboard"("limit_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_steam_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_steam_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_steam_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_superlative_suggestions_v2"("p_user_id" "uuid", "p_category" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_superlative_suggestions_v2"("p_user_id" "uuid", "p_category" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_superlative_suggestions_v2"("p_user_id" "uuid", "p_category" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_superlative_suggestions_v3"("p_user_id" "uuid", "p_category" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_superlative_suggestions_v3"("p_user_id" "uuid", "p_category" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_superlative_suggestions_v3"("p_user_id" "uuid", "p_category" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sweatiest_platinum_v2"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_sweatiest_platinum_v2"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sweatiest_platinum_v2"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unread_activity_count"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_unread_activity_count"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unread_activity_count"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_achievements_for_game"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_id" "text", "p_search_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_achievements_for_game"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_id" "text", "p_search_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_achievements_for_game"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_id" "text", "p_search_query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_completions"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_completions"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_completions"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_games_for_platform"("p_user_id" "uuid", "p_platform_id" bigint, "p_search_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_games_for_platform"("p_user_id" "uuid", "p_platform_id" bigint, "p_search_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_games_for_platform"("p_user_id" "uuid", "p_platform_id" bigint, "p_search_query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_psn_rank"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_psn_rank"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_psn_rank"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_steam_rank"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_steam_rank"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_steam_rank"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_trophy_counts"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_trophy_counts"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_trophy_counts"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_xbox_rank"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_xbox_rank"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_xbox_rank"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_xbox_leaderboard"("limit_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_xbox_leaderboard"("limit_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_xbox_leaderboard"("limit_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_xbox_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_xbox_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_xbox_leaderboard_with_movement"("limit_count" integer, "offset_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_activity_feed_viewed"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_activity_feed_viewed"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_activity_feed_viewed"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_game_groups_for_refresh"() TO "anon";
GRANT ALL ON FUNCTION "public"."mark_game_groups_for_refresh"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_game_groups_for_refresh"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_duplicate_email_profiles"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_duplicate_email_profiles"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_duplicate_email_profiles"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_achievement_rarity"() TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_achievement_rarity"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_achievement_rarity"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_user_progress_for_games"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_ids" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_user_progress_for_games"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_ids" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_user_progress_for_games"("p_user_id" "uuid", "p_platform_id" bigint, "p_platform_game_ids" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_game_groups"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_game_groups"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_game_groups"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_game_groups_if_needed"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_game_groups_if_needed"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_game_groups_if_needed"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_grouped_games_cache"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_grouped_games_cache"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_grouped_games_cache"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_leaderboard_cache"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_leaderboard_cache"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_leaderboard_cache"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_leaderboard_global_cache"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_leaderboard_global_cache"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_leaderboard_global_cache"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_psn_leaderboard_cache"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_psn_leaderboard_cache"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_psn_leaderboard_cache"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_statusxp_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_statusxp_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_statusxp_leaderboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_statusxp_leaderboard_for_user"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_statusxp_leaderboard_for_user"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_statusxp_leaderboard_for_user"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."snapshot_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."snapshot_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."snapshot_leaderboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."snapshot_psn_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."snapshot_psn_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."snapshot_psn_leaderboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."snapshot_steam_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."snapshot_steam_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."snapshot_steam_leaderboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."snapshot_xbox_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."snapshot_xbox_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."snapshot_xbox_leaderboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_calculate_statusxp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_calculate_statusxp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_calculate_statusxp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_refresh_leaderboards_on_sync"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_refresh_leaderboards_on_sync"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_refresh_leaderboards_on_sync"() TO "service_role";



GRANT ALL ON FUNCTION "public"."unlock_achievement_if_new"("p_user_id" "uuid", "p_achievement_id" "text", "p_unlocked_at" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."unlock_achievement_if_new"("p_user_id" "uuid", "p_achievement_id" "text", "p_unlocked_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."unlock_achievement_if_new"("p_user_id" "uuid", "p_achievement_id" "text", "p_unlocked_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_display_case_items_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_display_case_items_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_display_case_items_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_flex_room_data_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_flex_room_data_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_flex_room_data_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_flex_room_last_updated"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_flex_room_last_updated"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_flex_room_last_updated"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_leaderboard_on_achievements_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_leaderboard_on_achievements_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_leaderboard_on_achievements_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_leaderboard_on_progress_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_leaderboard_on_progress_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_leaderboard_on_progress_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_trophy_help_request_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_trophy_help_request_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_trophy_help_request_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_user_achievements_batch"("p_rows" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_user_achievements_batch"("p_rows" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_user_achievements_batch"("p_rows" "jsonb") TO "service_role";



GRANT ALL ON TABLE "public"."achievement_comments" TO "anon";
GRANT ALL ON TABLE "public"."achievement_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."achievement_comments" TO "service_role";



GRANT ALL ON TABLE "public"."achievements" TO "anon";
GRANT ALL ON TABLE "public"."achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."achievements" TO "service_role";



GRANT ALL ON TABLE "public"."activity_feed" TO "anon";
GRANT ALL ON TABLE "public"."activity_feed" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_feed" TO "service_role";



GRANT ALL ON SEQUENCE "public"."activity_feed_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."activity_feed_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."activity_feed_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."activity_feed_views" TO "anon";
GRANT ALL ON TABLE "public"."activity_feed_views" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_feed_views" TO "service_role";



GRANT ALL ON TABLE "public"."app_updates" TO "anon";
GRANT ALL ON TABLE "public"."app_updates" TO "authenticated";
GRANT ALL ON TABLE "public"."app_updates" TO "service_role";



GRANT ALL ON SEQUENCE "public"."app_updates_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."app_updates_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."app_updates_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."flex_room_data" TO "anon";
GRANT ALL ON TABLE "public"."flex_room_data" TO "authenticated";
GRANT ALL ON TABLE "public"."flex_room_data" TO "service_role";



GRANT ALL ON TABLE "public"."game_groups" TO "anon";
GRANT ALL ON TABLE "public"."game_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."game_groups" TO "service_role";



GRANT ALL ON SEQUENCE "public"."game_groups_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."game_groups_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."game_groups_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."game_groups_refresh_queue" TO "anon";
GRANT ALL ON TABLE "public"."game_groups_refresh_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."game_groups_refresh_queue" TO "service_role";



GRANT ALL ON SEQUENCE "public"."game_groups_refresh_queue_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."game_groups_refresh_queue_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."game_groups_refresh_queue_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."games" TO "anon";
GRANT ALL ON TABLE "public"."games" TO "authenticated";
GRANT ALL ON TABLE "public"."games" TO "service_role";



GRANT ALL ON TABLE "public"."platforms" TO "anon";
GRANT ALL ON TABLE "public"."platforms" TO "authenticated";
GRANT ALL ON TABLE "public"."platforms" TO "service_role";



GRANT ALL ON TABLE "public"."grouped_games_cache" TO "anon";
GRANT ALL ON TABLE "public"."grouped_games_cache" TO "authenticated";
GRANT ALL ON TABLE "public"."grouped_games_cache" TO "service_role";



GRANT ALL ON TABLE "public"."leaderboard_cache" TO "anon";
GRANT ALL ON TABLE "public"."leaderboard_cache" TO "authenticated";
GRANT ALL ON TABLE "public"."leaderboard_cache" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."user_achievements" TO "anon";
GRANT ALL ON TABLE "public"."user_achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."user_achievements" TO "service_role";



GRANT ALL ON TABLE "public"."leaderboard_global_cache" TO "anon";
GRANT ALL ON TABLE "public"."leaderboard_global_cache" TO "authenticated";
GRANT ALL ON TABLE "public"."leaderboard_global_cache" TO "service_role";



GRANT ALL ON TABLE "public"."leaderboard_history" TO "anon";
GRANT ALL ON TABLE "public"."leaderboard_history" TO "authenticated";
GRANT ALL ON TABLE "public"."leaderboard_history" TO "service_role";



GRANT ALL ON TABLE "public"."meta_achievements" TO "anon";
GRANT ALL ON TABLE "public"."meta_achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."meta_achievements" TO "service_role";



GRANT ALL ON SEQUENCE "public"."platforms_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."platforms_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."platforms_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profile_themes" TO "anon";
GRANT ALL ON TABLE "public"."profile_themes" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_themes" TO "service_role";



GRANT ALL ON SEQUENCE "public"."profile_themes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."profile_themes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."profile_themes_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."psn_leaderboard_cache" TO "anon";
GRANT ALL ON TABLE "public"."psn_leaderboard_cache" TO "authenticated";
GRANT ALL ON TABLE "public"."psn_leaderboard_cache" TO "service_role";



GRANT ALL ON TABLE "public"."psn_leaderboard_history" TO "anon";
GRANT ALL ON TABLE "public"."psn_leaderboard_history" TO "authenticated";
GRANT ALL ON TABLE "public"."psn_leaderboard_history" TO "service_role";



GRANT ALL ON TABLE "public"."psn_sync_logs" TO "anon";
GRANT ALL ON TABLE "public"."psn_sync_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."psn_sync_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."psn_sync_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."psn_sync_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."psn_sync_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."psn_user_trophy_profile" TO "anon";
GRANT ALL ON TABLE "public"."psn_user_trophy_profile" TO "authenticated";
GRANT ALL ON TABLE "public"."psn_user_trophy_profile" TO "service_role";



GRANT ALL ON TABLE "public"."steam_leaderboard_cache" TO "anon";
GRANT ALL ON TABLE "public"."steam_leaderboard_cache" TO "authenticated";
GRANT ALL ON TABLE "public"."steam_leaderboard_cache" TO "service_role";



GRANT ALL ON TABLE "public"."steam_leaderboard_history" TO "anon";
GRANT ALL ON TABLE "public"."steam_leaderboard_history" TO "authenticated";
GRANT ALL ON TABLE "public"."steam_leaderboard_history" TO "service_role";



GRANT ALL ON TABLE "public"."steam_sync_logs" TO "anon";
GRANT ALL ON TABLE "public"."steam_sync_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."steam_sync_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."steam_sync_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."steam_sync_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."steam_sync_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."trophy_help_requests" TO "anon";
GRANT ALL ON TABLE "public"."trophy_help_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."trophy_help_requests" TO "service_role";



GRANT ALL ON TABLE "public"."trophy_help_responses" TO "anon";
GRANT ALL ON TABLE "public"."trophy_help_responses" TO "authenticated";
GRANT ALL ON TABLE "public"."trophy_help_responses" TO "service_role";



GRANT ALL ON TABLE "public"."trophy_room_items" TO "anon";
GRANT ALL ON TABLE "public"."trophy_room_items" TO "authenticated";
GRANT ALL ON TABLE "public"."trophy_room_items" TO "service_role";



GRANT ALL ON SEQUENCE "public"."trophy_room_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."trophy_room_items_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."trophy_room_items_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."trophy_room_shelves" TO "anon";
GRANT ALL ON TABLE "public"."trophy_room_shelves" TO "authenticated";
GRANT ALL ON TABLE "public"."trophy_room_shelves" TO "service_role";



GRANT ALL ON SEQUENCE "public"."trophy_room_shelves_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."trophy_room_shelves_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."trophy_room_shelves_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_ai_credits" TO "anon";
GRANT ALL ON TABLE "public"."user_ai_credits" TO "authenticated";
GRANT ALL ON TABLE "public"."user_ai_credits" TO "service_role";



GRANT ALL ON TABLE "public"."user_ai_daily_usage" TO "anon";
GRANT ALL ON TABLE "public"."user_ai_daily_usage" TO "authenticated";
GRANT ALL ON TABLE "public"."user_ai_daily_usage" TO "service_role";



GRANT ALL ON TABLE "public"."user_ai_pack_purchases" TO "anon";
GRANT ALL ON TABLE "public"."user_ai_pack_purchases" TO "authenticated";
GRANT ALL ON TABLE "public"."user_ai_pack_purchases" TO "service_role";



GRANT ALL ON TABLE "public"."user_premium_status" TO "anon";
GRANT ALL ON TABLE "public"."user_premium_status" TO "authenticated";
GRANT ALL ON TABLE "public"."user_premium_status" TO "service_role";



GRANT ALL ON TABLE "public"."user_ai_status" TO "anon";
GRANT ALL ON TABLE "public"."user_ai_status" TO "authenticated";
GRANT ALL ON TABLE "public"."user_ai_status" TO "service_role";



GRANT ALL ON TABLE "public"."user_progress" TO "anon";
GRANT ALL ON TABLE "public"."user_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."user_progress" TO "service_role";



GRANT ALL ON TABLE "public"."user_games" TO "anon";
GRANT ALL ON TABLE "public"."user_games" TO "authenticated";
GRANT ALL ON TABLE "public"."user_games" TO "service_role";



GRANT ALL ON TABLE "public"."user_meta_achievements" TO "anon";
GRANT ALL ON TABLE "public"."user_meta_achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."user_meta_achievements" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_meta_achievements_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_meta_achievements_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_meta_achievements_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_profile_settings" TO "anon";
GRANT ALL ON TABLE "public"."user_profile_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."user_profile_settings" TO "service_role";



GRANT ALL ON TABLE "public"."user_selected_title" TO "anon";
GRANT ALL ON TABLE "public"."user_selected_title" TO "authenticated";
GRANT ALL ON TABLE "public"."user_selected_title" TO "service_role";



GRANT ALL ON TABLE "public"."user_stat_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."user_stat_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."user_stat_snapshots" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_stat_snapshots_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_stat_snapshots_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_stat_snapshots_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_stats" TO "anon";
GRANT ALL ON TABLE "public"."user_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."user_stats" TO "service_role";



GRANT ALL ON TABLE "public"."user_sync_history" TO "anon";
GRANT ALL ON TABLE "public"."user_sync_history" TO "authenticated";
GRANT ALL ON TABLE "public"."user_sync_history" TO "service_role";



GRANT ALL ON TABLE "public"."user_sync_status" TO "anon";
GRANT ALL ON TABLE "public"."user_sync_status" TO "authenticated";
GRANT ALL ON TABLE "public"."user_sync_status" TO "service_role";



GRANT ALL ON TABLE "public"."xbox_leaderboard_cache" TO "anon";
GRANT ALL ON TABLE "public"."xbox_leaderboard_cache" TO "authenticated";
GRANT ALL ON TABLE "public"."xbox_leaderboard_cache" TO "service_role";



GRANT ALL ON TABLE "public"."xbox_leaderboard_history" TO "anon";
GRANT ALL ON TABLE "public"."xbox_leaderboard_history" TO "authenticated";
GRANT ALL ON TABLE "public"."xbox_leaderboard_history" TO "service_role";



GRANT ALL ON TABLE "public"."xbox_sync_logs" TO "anon";
GRANT ALL ON TABLE "public"."xbox_sync_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."xbox_sync_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."xbox_sync_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."xbox_sync_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."xbox_sync_logs_id_seq" TO "service_role";



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







