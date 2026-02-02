-- Add Potential Stats to All Leaderboard Caches (FIXED)
-- Run in Supabase SQL Editor: https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new

-- ============================================================================
-- 1. UPDATE STATUSXP CACHE (BASE TABLE - can ALTER)
-- ============================================================================

ALTER TABLE leaderboard_cache 
ADD COLUMN IF NOT EXISTS potential_statusxp bigint DEFAULT 0,
ADD COLUMN IF NOT EXISTS display_name text,
ADD COLUMN IF NOT EXISTS avatar_url text;

-- ============================================================================
-- 2. RECREATE XBOX CACHE VIEW with potential_gamerscore
-- ============================================================================

DROP VIEW IF EXISTS xbox_leaderboard_cache CASCADE;

CREATE VIEW xbox_leaderboard_cache AS
WITH xbox_user_stats AS (
  -- First aggregate per game to avoid multiplication
  SELECT 
    up.user_id,
    -- Sum gamerscore per game (ONE value per game)
    SUM(up.current_score) as total_gamerscore,
    -- Sum potential gamerscore (max_score from metadata)
    SUM(COALESCE((up.metadata->>'max_gamerscore')::integer, 0)) as potential_gamerscore,
    -- Count unique games
    COUNT(DISTINCT (up.platform_id, up.platform_game_id)) as total_games
  FROM user_progress up
  WHERE up.platform_id IN (10, 11, 12) -- Xbox 360, One, Series X/S
  GROUP BY up.user_id
),
xbox_achievement_count AS (
  -- Count total achievements separately
  SELECT 
    ua.user_id,
    COUNT(*) as achievement_count
  FROM user_achievements ua
  WHERE ua.platform_id IN (10, 11, 12)
  GROUP BY ua.user_id
)
SELECT 
  xus.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') as display_name,
  p.xbox_avatar_url as avatar_url,
  COALESCE(xac.achievement_count, 0) as achievement_count,
  xus.total_games,
  COALESCE(xus.total_gamerscore, 0) as gamerscore,
  COALESCE(xus.potential_gamerscore, 0) as potential_gamerscore,
  now() as updated_at
FROM xbox_user_stats xus
JOIN profiles p ON p.id = xus.user_id
LEFT JOIN xbox_achievement_count xac ON xac.user_id = xus.user_id
WHERE p.show_on_leaderboard = true
ORDER BY gamerscore DESC, achievement_count DESC, total_games DESC;

-- ============================================================================
-- 3. RECREATE STEAM CACHE VIEW with potential_achievements
-- ============================================================================

DROP VIEW IF EXISTS steam_leaderboard_cache CASCADE;

CREATE VIEW steam_leaderboard_cache AS
WITH steam_achievement_stats AS (
  -- Count earned achievements
  SELECT 
    ua.user_id,
    COUNT(*) as achievement_count,
    COUNT(DISTINCT a.platform_game_id) as total_games
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id = 4
  GROUP BY ua.user_id
),
steam_potential_achievements AS (
  -- Count total possible achievements from games user has
  SELECT 
    ua.user_id,
    COUNT(DISTINCT a.platform_achievement_id) as potential_achievements
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
  WHERE ua.platform_id = 4
  GROUP BY ua.user_id, a.platform_game_id
)
SELECT 
  sas.user_id,
  COALESCE(p.steam_display_name, p.display_name, p.username, 'Player') as display_name,
  p.steam_avatar_url as avatar_url,
  COALESCE(sas.achievement_count, 0)::bigint as achievement_count,
  COALESCE(SUM(spa.potential_achievements), 0)::bigint as potential_achievements,
  sas.total_games::bigint,
  now() as updated_at
FROM steam_achievement_stats sas
JOIN profiles p ON p.id = sas.user_id
LEFT JOIN steam_potential_achievements spa ON spa.user_id = sas.user_id
WHERE p.show_on_leaderboard = true
GROUP BY sas.user_id, p.steam_display_name, p.display_name, p.username, p.steam_avatar_url, sas.achievement_count, sas.total_games
ORDER BY achievement_count DESC, total_games DESC;

-- ============================================================================
-- 4. UPDATE RPC FUNCTIONS
-- ============================================================================

-- Xbox with potential_gamerscore
DROP FUNCTION IF EXISTS get_xbox_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_xbox_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  gamerscore bigint,
  potential_gamerscore bigint,
  achievement_count bigint,
  total_games bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
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

-- Steam with potential_achievements
DROP FUNCTION IF EXISTS get_steam_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_steam_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  achievement_count bigint,
  potential_achievements bigint,
  total_games bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
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

-- StatusXP with potential_statusxp (calculated from user_progress)
DROP FUNCTION IF EXISTS get_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_statusxp bigint,
  potential_statusxp bigint,
  total_game_entries integer,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH user_potential_statusxp AS (
    -- Calculate potential StatusXP: sum of max possible from all games user has progress on
    SELECT 
      up.user_id,
      COALESCE(SUM((up.metadata->>'max_score')::bigint), 0) as potential_statusxp
    FROM user_progress up
    WHERE (up.metadata->>'max_score') IS NOT NULL
    GROUP BY up.user_id
  ),
  current_leaderboard AS (
    SELECT 
      lc.user_id,
      COALESCE(lc.display_name, p.display_name, p.username, 'Player') as display_name,
      COALESCE(lc.avatar_url, p.psn_avatar_url, p.xbox_avatar_url, p.steam_avatar_url) as avatar_url,
      lc.total_statusxp::bigint,
      COALESCE(ups.potential_statusxp, 0)::bigint as potential_statusxp,
      lc.total_game_entries,
      ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC) as current_rank
    FROM leaderboard_cache lc
    LEFT JOIN profiles p ON p.id = lc.user_id
    LEFT JOIN user_potential_statusxp ups ON ups.user_id = lc.user_id
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.total_statusxp,
    cl.potential_statusxp,
    cl.total_game_entries,
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

-- PSN with trophy breakdown (already has all trophy counts)
DROP FUNCTION IF EXISTS get_psn_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_psn_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  platinum_count bigint,
  gold_count bigint,
  silver_count bigint,
  bronze_count bigint,
  total_trophies bigint,
  total_games bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
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

-- Grant permissions on views
GRANT SELECT ON xbox_leaderboard_cache TO authenticated;
GRANT SELECT ON xbox_leaderboard_cache TO anon;
GRANT SELECT ON steam_leaderboard_cache TO authenticated;
GRANT SELECT ON steam_leaderboard_cache TO anon;

-- ============================================================================
-- TEST ALL FUNCTIONS
-- ============================================================================

-- Test PSN (should show trophy breakdown: Platinum | Gold | Silver | Bronze)
SELECT 
  display_name,
  platinum_count || ' | ' || gold_count || ' | ' || silver_count || ' | ' || bronze_count as trophy_breakdown,
  is_new
FROM get_psn_leaderboard_with_movement(3, 0);

-- Test Xbox (should show gamerscore | potential)
SELECT 
  display_name,
  gamerscore || ' | ' || potential_gamerscore as "gamerscore | potential",
  is_new
FROM get_xbox_leaderboard_with_movement(3, 0);

-- Test Steam (should show achievements | potential)
SELECT 
  display_name,
  achievement_count || ' | ' || potential_achievements as "achievements | potential",
  is_new
FROM get_steam_leaderboard_with_movement(3, 0);

-- Test StatusXP (should show statusxp | potential)
SELECT 
  display_name,
  total_statusxp || ' | ' || potential_statusxp as "statusxp | potential",
  is_new
FROM get_leaderboard_with_movement(3, 0);
