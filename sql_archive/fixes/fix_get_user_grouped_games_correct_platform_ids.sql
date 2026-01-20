-- ============================================================================
-- FIX get_user_grouped_games - Correct Xbox platform IDs
-- ============================================================================
-- Platform IDs should be: PSN=1, Steam=5, Xbox360=10, XboxOne=11, XboxSeriesX=12
-- ============================================================================

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
    g.cover_url as proxied_cover_url,
    ARRAY[
      jsonb_build_object(
        'code', CASE 
          WHEN g.platform_id = 1 THEN 'PS5'
          WHEN g.platform_id = 5 THEN 'Steam'
          WHEN g.platform_id = 10 THEN 'XBOX360'
          WHEN g.platform_id = 11 THEN 'XBOXONE'
          WHEN g.platform_id = 12 THEN 'XBOXSERIESX'
          ELSE 'unknown'
        END,
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
            SELECT SUM(a.base_status_xp * COALESCE(a.rarity_multiplier::numeric, 1.0))
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
        'last_trophy_earned_at', (
          SELECT MAX(ua.earned_at)
          FROM user_achievements ua
          WHERE ua.user_id = p_user_id
            AND ua.platform_id = g.platform_id
            AND ua.platform_game_id = g.platform_game_id
        ),
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
        SELECT SUM(a.base_status_xp * COALESCE(a.rarity_multiplier::numeric, 1.0))
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
    up.last_played_at,
    ARRAY[0::BIGINT] as game_title_ids
  FROM games g
  INNER JOIN user_progress up ON up.platform_id = g.platform_id
    AND up.platform_game_id = g.platform_game_id
  WHERE up.user_id = p_user_id
  ORDER BY up.last_played_at DESC NULLS LAST, g.name;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_grouped_games(UUID) TO authenticated;

-- Verify it works
SELECT 
  name,
  (platforms[1]->>'code') as platform,
  (platforms[1]->>'earned_trophies')::int as earned,
  (platforms[1]->>'total_trophies')::int as total
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid)
WHERE (platforms[1]->>'code') IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX', 'Steam')
LIMIT 10;
