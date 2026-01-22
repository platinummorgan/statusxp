-- Migration 1012: Update get_user_grouped_games to use current schema
-- This function is used by the dashboard to display user's games sorted by last played

-- Drop existing function
DROP FUNCTION IF EXISTS get_user_grouped_games(UUID);

-- Recreate function using actual schema (games, user_progress, achievements, user_achievements)
CREATE OR REPLACE FUNCTION get_user_grouped_games(p_user_id UUID)
RETURNS TABLE (
  group_id TEXT,
  name TEXT,
  cover_url TEXT,
  proxied_cover_url TEXT,
  platforms JSONB[],
  total_statusxp NUMERIC,
  avg_completion NUMERIC,
  last_played_at TIMESTAMPTZ,
  game_title_ids BIGINT[]
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    -- Use composite key as group_id (platform_id + platform_game_id)
    (g.platform_id || '_' || g.platform_game_id)::TEXT as group_id,
    g.name,
    g.cover_url,
    -- Return proxied cover URL if already proxied
    CASE 
      WHEN g.cover_url LIKE '%cloudfront%' OR g.cover_url LIKE '%supabase%' 
      THEN g.cover_url
      ELSE NULL
    END as proxied_cover_url,
    -- Create single-platform array
    ARRAY[jsonb_build_object(
      'platform', LOWER(
        CASE 
          WHEN p.code IN ('PS3', 'PS4', 'PS5', 'PSVITA') THEN 'psn'
          WHEN p.code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX') THEN 'xbox'
          WHEN p.code = 'Steam' THEN 'steam'
          ELSE 'unknown'
        END
      ),
      'platform_id', g.platform_id,
      'platform_game_id', g.platform_game_id,
      'completion', up.completion_percentage,
      'statusxp', (
        SELECT COALESCE(SUM(a.base_status_xp), 0)
        FROM user_achievements ua
        JOIN achievements a ON a.platform_id = ua.platform_id
          AND a.platform_game_id = ua.platform_game_id
          AND a.platform_achievement_id = ua.platform_achievement_id
        WHERE ua.user_id = p_user_id
          AND ua.platform_id = g.platform_id
          AND ua.platform_game_id = g.platform_game_id
      ),
      'earned_trophies', up.achievements_earned,
      'total_trophies', up.total_achievements,
      'bronze_trophies', (
        SELECT COUNT(*) FROM user_achievements ua 
        JOIN achievements a ON a.platform_id = ua.platform_id 
          AND a.platform_game_id = ua.platform_game_id 
          AND a.platform_achievement_id = ua.platform_achievement_id
        WHERE ua.user_id = p_user_id 
          AND ua.platform_id = g.platform_id 
          AND ua.platform_game_id = g.platform_game_id
          AND a.metadata->>'psn_trophy_type' = 'bronze'
      ),
      'silver_trophies', (
        SELECT COUNT(*) FROM user_achievements ua 
        JOIN achievements a ON a.platform_id = ua.platform_id 
          AND a.platform_game_id = ua.platform_game_id 
          AND a.platform_achievement_id = ua.platform_achievement_id
        WHERE ua.user_id = p_user_id 
          AND ua.platform_id = g.platform_id 
          AND ua.platform_game_id = g.platform_game_id
          AND a.metadata->>'psn_trophy_type' = 'silver'
      ),
      'gold_trophies', (
        SELECT COUNT(*) FROM user_achievements ua 
        JOIN achievements a ON a.platform_id = ua.platform_id 
          AND a.platform_game_id = ua.platform_game_id 
          AND a.platform_achievement_id = ua.platform_achievement_id
        WHERE ua.user_id = p_user_id 
          AND ua.platform_id = g.platform_id 
          AND ua.platform_game_id = g.platform_game_id
          AND a.metadata->>'psn_trophy_type' = 'gold'
      ),
      'platinum_trophies', (
        SELECT COUNT(*) FROM user_achievements ua 
        JOIN achievements a ON a.platform_id = ua.platform_id 
          AND a.platform_game_id = ua.platform_game_id 
          AND a.platform_achievement_id = ua.platform_achievement_id
        WHERE ua.user_id = p_user_id 
          AND ua.platform_id = g.platform_id 
          AND ua.platform_game_id = g.platform_game_id
          AND a.is_platinum = true
      ),
      'last_played_at', up.last_played_at,
      'last_trophy_earned_at', up.last_achievement_earned_at,
      'rarest_achievement_rarity', (
        SELECT MIN((a.metadata->>'rarity')::NUMERIC)
        FROM user_achievements ua 
        JOIN achievements a ON a.platform_id = ua.platform_id 
          AND a.platform_game_id = ua.platform_game_id 
          AND a.platform_achievement_id = ua.platform_achievement_id
        WHERE ua.user_id = p_user_id 
          AND ua.platform_id = g.platform_id 
          AND ua.platform_game_id = g.platform_game_id
          AND a.metadata->>'rarity' IS NOT NULL
      ),
      'gamerscore', up.current_score
    )] as platforms,
    (
      SELECT COALESCE(SUM(a.base_status_xp), 0)
      FROM user_achievements ua
      JOIN achievements a ON a.platform_id = ua.platform_id
        AND a.platform_game_id = ua.platform_game_id
        AND a.platform_achievement_id = ua.platform_achievement_id
      WHERE ua.user_id = p_user_id
        AND ua.platform_id = g.platform_id
        AND ua.platform_game_id = g.platform_game_id
    ) as total_statusxp,
    COALESCE(up.completion_percentage, 0) as avg_completion,
    up.last_played_at,
    ARRAY[]::BIGINT[] as game_title_ids  -- Empty array for backward compatibility
  FROM games g
  INNER JOIN user_progress up ON up.user_id = p_user_id 
    AND up.platform_id = g.platform_id 
    AND up.platform_game_id = g.platform_game_id
  INNER JOIN platforms p ON p.id = g.platform_id
  ORDER BY up.last_played_at DESC NULLS LAST;
END;
$$;
