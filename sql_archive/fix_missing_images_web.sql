-- Fix get_user_grouped_games to return cover_url for proxied_cover_url instead of NULL
-- This allows external PSN/Xbox/Steam URLs to display on web

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
  SELECT 
    ('group_' || ug.game_title_id::TEXT) as group_id,
    ug.game_title as name,
    g.cover_url,
    g.cover_url as proxied_cover_url,  -- FIXED: Return actual URL instead of NULL
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
      'statusxp', 0,
      'game_title_id', ug.game_title_id,
      'earned_trophies', ug.earned_trophies,
      'total_trophies', ug.total_trophies,
      'bronze_trophies', ug.bronze_trophies,
      'silver_trophies', ug.silver_trophies,
      'gold_trophies', ug.gold_trophies,
      'platinum_trophies', ug.platinum_trophies,
      'xbox_achievements_earned', ug.earned_trophies,
      'xbox_total_achievements', ug.total_trophies
    )] as platforms,
    0::NUMERIC as total_statusxp,
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
