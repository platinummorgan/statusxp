-- ROLLBACK: Fix StatusXP = 0 and missing Xbox gamerscore in My Games
-- Reverts to previous version of get_user_grouped_games

CREATE OR REPLACE FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") 
RETURNS TABLE(
  "group_id" "text", 
  "name" "text", 
  "cover_url" "text", 
  "proxied_cover_url" "text", 
  "platforms" "jsonb"[], 
  "total_statusxp" numeric, 
  "avg_completion" numeric, 
  "last_played_at" timestamp with time zone, 
  "game_title_ids" bigint[]
)
LANGUAGE "plpgsql"
AS $$
BEGIN
  RETURN QUERY
  WITH game_statusxp AS (
    -- Calculate StatusXP per game by summing earned achievements' base_status_xp
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      SUM(a.base_status_xp)::INTEGER as statusxp
    FROM user_achievements ua
    JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id 
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.include_in_score = true
    GROUP BY ua.platform_id, ua.platform_game_id
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

COMMENT ON FUNCTION "public"."get_user_grouped_games"("p_user_id" "uuid") IS 'Returns user games grouped by title with actual StatusXP calculated from earned achievements. Fixed Jan 22, 2026 - was hardcoded to 0.';
