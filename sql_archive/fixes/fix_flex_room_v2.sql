-- Flex Room V2 Migration: Update RPC functions to use composite keys
-- This replaces the V1 schema queries with V2 composite key queries

-- Drop existing functions first since we're changing return types
DROP FUNCTION IF EXISTS get_rarest_achievement_v2(UUID);
DROP FUNCTION IF EXISTS get_most_time_sunk_game_v2(UUID);
DROP FUNCTION IF EXISTS get_sweatiest_platinum_v2(UUID);
DROP FUNCTION IF EXISTS get_recent_notable_achievements_v2(UUID, INT);
DROP FUNCTION IF EXISTS get_superlative_suggestions_v2(UUID, TEXT);

-- Get user's rarest achievement across all platforms
CREATE OR REPLACE FUNCTION get_rarest_achievement_v2(p_user_id UUID)
RETURNS TABLE (
  platform_id BIGINT,
  platform_game_id TEXT,
  platform_achievement_id TEXT,
  earned_at TIMESTAMPTZ,
  rarity_global NUMERIC,
  achievement_name TEXT,
  achievement_icon_url TEXT,
  game_name TEXT,
  game_cover_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    a.icon_url as achievement_icon_url,
    g.name as game_name,
    g.cover_url as game_cover_url
  FROM user_achievements ua
  INNER JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  INNER JOIN games g ON
    g.platform_id = ua.platform_id
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = p_user_id
    AND a.rarity_global IS NOT NULL
  ORDER BY a.rarity_global ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get game with most achievements earned (time sunk) - returns a representative achievement
CREATE OR REPLACE FUNCTION get_most_time_sunk_game_v2(p_user_id UUID)
RETURNS TABLE (
  platform_id BIGINT,
  platform_game_id TEXT,
  platform_achievement_id TEXT,
  earned_at TIMESTAMPTZ,
  achievement_name TEXT,
  achievement_icon_url TEXT,
  game_name TEXT,
  game_cover_url TEXT,
  rarity_global NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH game_counts AS (
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      COUNT(*) as achievement_count
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
    a.name as achievement_name,
    a.icon_url as achievement_icon_url,
    g.name as game_name,
    g.cover_url as game_cover_url,
    a.rarity_global
  FROM user_achievements ua
  INNER JOIN game_counts gc ON 
    gc.platform_id = ua.platform_id
    AND gc.platform_game_id = ua.platform_game_id
  INNER JOIN achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  INNER JOIN games g ON
    g.platform_id = ua.platform_id
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = p_user_id
  ORDER BY ua.earned_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get rarest platinum trophy (sweatiest)
CREATE OR REPLACE FUNCTION get_sweatiest_platinum_v2(p_user_id UUID)
RETURNS TABLE (
  platform_id BIGINT,
  platform_game_id TEXT,
  platform_achievement_id TEXT,
  earned_at TIMESTAMPTZ,
  rarity_global NUMERIC,
  achievement_name TEXT,
  achievement_icon_url TEXT,
  game_name TEXT,
  game_cover_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    a.icon_url as achievement_icon_url,
    g.name as game_name,
    g.cover_url as game_cover_url
  FROM user_achievements ua
  INNER JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  INNER JOIN games g ON
    g.platform_id = ua.platform_id
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id = 1 -- PSN
    AND a.metadata->>'psn_trophy_type' = 'platinum'
    AND a.rarity_global IS NOT NULL
  ORDER BY a.rarity_global ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get recent notable achievements (platinums and ultra-rares < 5%)
CREATE OR REPLACE FUNCTION get_recent_notable_achievements_v2(p_user_id UUID, p_limit INT DEFAULT 5)
RETURNS TABLE (
  platform_id BIGINT,
  platform_game_id TEXT,
  platform_achievement_id TEXT,
  earned_at TIMESTAMPTZ,
  rarity_global NUMERIC,
  is_platinum BOOLEAN,
  achievement_name TEXT,
  achievement_icon_url TEXT,
  game_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    (a.metadata->>'psn_trophy_type' = 'platinum') as is_platinum,
    a.name as achievement_name,
    a.icon_url as achievement_icon_url,
    g.name as game_name
  FROM user_achievements ua
  INNER JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  INNER JOIN games g ON
    g.platform_id = ua.platform_id
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = p_user_id
    AND (
      a.metadata->>'psn_trophy_type' = 'platinum'
      OR a.rarity_global < 5.0
    )
  ORDER BY ua.earned_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get smart suggestions for superlative categories
CREATE OR REPLACE FUNCTION get_superlative_suggestions_v2(
  p_user_id UUID,
  p_category TEXT
)
RETURNS TABLE (
  platform_id BIGINT,
  platform_game_id TEXT,
  platform_achievement_id TEXT,
  earned_at TIMESTAMPTZ,
  score NUMERIC
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_rarest_achievement_v2(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_most_time_sunk_game_v2(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_sweatiest_platinum_v2(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recent_notable_achievements_v2(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_superlative_suggestions_v2(UUID, TEXT) TO authenticated;
