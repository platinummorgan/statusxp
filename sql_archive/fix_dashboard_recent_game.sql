-- ============================================================================
-- FIX DASHBOARD RECENT GAME DISPLAY
-- ============================================================================
-- Problem: Dashboard not showing most recent game with latest trophy
-- Root Cause: get_user_grouped_games() function queries V1 schema (game_titles, user_games)
--             and doesn't return last_trophy_earned_at field
-- Solution: Update to V2 schema (games, user_progress) and include last_trophy_earned_at

-- Step 1: Add last_achievement_earned_at column to user_progress if it doesn't exist
ALTER TABLE user_progress ADD COLUMN IF NOT EXISTS last_achievement_earned_at TIMESTAMPTZ;

-- Step 2: Backfill last_achievement_earned_at with existing achievement data
UPDATE user_progress up
SET last_achievement_earned_at = (
  SELECT MAX(ua.earned_at)
  FROM user_achievements ua
  WHERE ua.user_id = up.user_id
    AND ua.platform_id = up.platform_id
    AND ua.platform_game_id = up.platform_game_id
)
WHERE up.last_achievement_earned_at IS NULL;

-- Step 3: Update function to use V2 schema
DROP FUNCTION IF EXISTS get_user_grouped_games(UUID);

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
    CONCAT(g.platform_id::text, '-', g.platform_game_id) as group_id,
    g.name,
    g.cover_url,
    g.cover_url as proxied_cover_url,  -- Use same as cover_url
    ARRAY[
      jsonb_build_object(
        'code', p.code,
        'game_title_id', g.platform_game_id,
        'platform_id', g.platform_id,
        'platform_game_id', g.platform_game_id,
        'completion', COALESCE(
          CASE 
            WHEN up.total_achievements > 0 
            THEN (up.achievements_earned::NUMERIC / up.total_achievements * 100)
            ELSE 0
          END, 0
        ),
        'statusxp', COALESCE(
          (
            SELECT SUM(a.base_status_xp)
            FROM user_achievements ua
            JOIN achievements a ON a.platform_id = ua.platform_id
              AND a.platform_game_id = ua.platform_game_id
              AND a.platform_achievement_id = ua.platform_achievement_id
            WHERE ua.user_id = p_user_id
              AND ua.platform_id = g.platform_id
              AND ua.platform_game_id = g.platform_game_id
          ), 0
        ),
        'earned_trophies', COALESCE(up.achievements_earned, 0),
        'total_trophies', COALESCE(up.total_achievements, 0),
        'bronze_trophies', COALESCE((up.metadata->>'bronze_trophies')::integer, 0),
        'silver_trophies', COALESCE((up.metadata->>'silver_trophies')::integer, 0),
        'gold_trophies', COALESCE((up.metadata->>'gold_trophies')::integer, 0),
        'platinum_trophies', COALESCE((up.metadata->>'platinum_trophies')::integer, 0),
        'xbox_achievements_earned', COALESCE(up.achievements_earned, 0),
        'xbox_total_achievements', COALESCE(up.total_achievements, 0),
        'last_played_at', up.last_played_at,
        'last_trophy_earned_at', up.last_achievement_earned_at,  -- CRITICAL: Use last_achievement_earned_at from user_progress
        'rarest_achievement_rarity', (
          SELECT MIN(a.rarity_global)
          FROM user_achievements ua
          JOIN achievements a ON a.platform_id = ua.platform_id
            AND a.platform_game_id = ua.platform_game_id
            AND a.platform_achievement_id = ua.platform_achievement_id
          WHERE ua.user_id = p_user_id
            AND ua.platform_id = g.platform_id
            AND ua.platform_game_id = g.platform_game_id
        )
      )
    ] as platforms,
    COALESCE(
      (
        SELECT SUM(a.base_status_xp)
        FROM user_achievements ua
        JOIN achievements a ON a.platform_id = ua.platform_id
          AND a.platform_game_id = ua.platform_game_id
          AND a.platform_achievement_id = ua.platform_achievement_id
        WHERE ua.user_id = p_user_id
          AND ua.platform_id = g.platform_id
          AND ua.platform_game_id = g.platform_game_id
      ), 0
    )::NUMERIC as total_statusxp,
    COALESCE(
      CASE 
        WHEN up.total_achievements > 0 
        THEN (up.achievements_earned::NUMERIC / up.total_achievements * 100)
        ELSE 0
      END, 0
    )::NUMERIC as avg_completion,
    COALESCE(up.last_achievement_earned_at, up.last_played_at) as last_played_at,  -- Prefer last_achievement_earned_at for sorting
    ARRAY[0::BIGINT] as game_title_ids  -- Legacy field
  FROM games g
  INNER JOIN user_progress up ON up.platform_id = g.platform_id
    AND up.platform_game_id = g.platform_game_id
  INNER JOIN platforms p ON p.id = g.platform_id
  WHERE up.user_id = p_user_id
  ORDER BY 
    COALESCE(up.last_achievement_earned_at, up.last_played_at) DESC NULLS LAST,
    g.name;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_grouped_games(UUID) TO authenticated;

-- Test query to verify function returns last_trophy_earned_at
SELECT 
  name,
  (platforms[1]->>'last_trophy_earned_at') as last_trophy_earned_at,
  last_played_at
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid)
LIMIT 10;
