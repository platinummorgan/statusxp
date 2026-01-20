-- Efficient function to get user's games for a platform
-- Single query with JOIN and GROUP BY instead of N+1 queries

-- Drop existing functions to avoid return type conflicts
DROP FUNCTION IF EXISTS get_user_games_for_platform(UUID, BIGINT, TEXT);
DROP FUNCTION IF EXISTS get_user_achievements_for_game(UUID, BIGINT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_user_games_for_platform(
  p_user_id UUID,
  p_platform_id BIGINT,
  p_search_query TEXT DEFAULT NULL
)
RETURNS TABLE (
  platform_id BIGINT,
  platform_game_id TEXT,
  game_name TEXT,
  cover_url TEXT,
  achievement_count BIGINT
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_user_games_for_platform(UUID, BIGINT, TEXT) TO authenticated;

-- Efficient function to get user's achievements for a specific game
CREATE OR REPLACE FUNCTION get_user_achievements_for_game(
  p_user_id UUID,
  p_platform_id BIGINT,
  p_platform_game_id TEXT,
  p_search_query TEXT DEFAULT NULL
)
RETURNS TABLE (
  platform_achievement_id TEXT,
  achievement_name TEXT,
  game_name TEXT,
  cover_url TEXT,
  icon_url TEXT,
  rarity_global NUMERIC,
  earned_at TIMESTAMPTZ
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_user_achievements_for_game(UUID, BIGINT, TEXT, TEXT) TO authenticated;
