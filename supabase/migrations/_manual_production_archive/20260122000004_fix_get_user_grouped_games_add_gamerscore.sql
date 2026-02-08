-- Add current_score (gamerscore for Xbox, trophy points for PSN) to get_user_grouped_games
-- This enables UX enhancement for Xbox games to display "Achievement Points 300/1000"

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
    -- Calculate actual StatusXP from earned achievements
    SELECT 
      ug.game_title_id,
      ug.platform_id,
      ug.user_id,
      COALESCE(SUM(
        CASE 
          WHEN a.include_in_score THEN a.base_status_xp 
          ELSE 0 
        END
      ), 0) AS statusxp
    FROM user_games ug
    LEFT JOIN games g ON g.platform_id = ug.platform_id 
      AND (('x'::text || substr(md5((ug.platform_id::text || '_'::text) || g.platform_game_id), 1, 15)))::bit(60)::bigint = ug.game_title_id
    LEFT JOIN user_achievements ua ON ua.user_id = ug.user_id 
      AND ua.platform_id = ug.platform_id 
      AND ua.platform_game_id = g.platform_game_id
    LEFT JOIN achievements a ON a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id 
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ug.user_id = p_user_id
    GROUP BY ug.game_title_id, ug.platform_id, ug.user_id
  ),
  game_totals AS (
    -- Calculate total achievements and gamerscore per game
    SELECT 
      ug.game_title_id,
      ug.platform_id,
      COUNT(a.platform_achievement_id) AS total_achievements,
      COALESCE(SUM(a.score_value), 0) AS total_gamerscore
    FROM user_games ug
    LEFT JOIN games g ON g.platform_id = ug.platform_id 
      AND (('x'::text || substr(md5((ug.platform_id::text || '_'::text) || g.platform_game_id), 1, 15)))::bit(60)::bigint = ug.game_title_id
    LEFT JOIN achievements a ON a.platform_id = g.platform_id 
      AND a.platform_game_id = g.platform_game_id
    WHERE ug.user_id = p_user_id
    GROUP BY ug.game_title_id, ug.platform_id
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
      'earned_trophies', ug.earned_trophies,
      'total_trophies', COALESCE(gt.total_achievements, ug.total_trophies),
      'bronze_trophies', ug.bronze_trophies,
      'silver_trophies', ug.silver_trophies,
      'gold_trophies', ug.gold_trophies,
      'platinum_trophies', ug.platinum_trophies,
      'xbox_achievements_earned', ug.earned_trophies,
      'xbox_total_achievements', COALESCE(gt.total_achievements, ug.total_trophies),
      'platform_id', ug.platform_id,
      'platform_game_id', g.platform_game_id,
      'current_score', COALESCE(ug.current_score, 0),
      'total_score', COALESCE(gt.total_gamerscore, 0)
    )] as platforms,
    COALESCE(gs.statusxp, 0) as total_statusxp,
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
  LEFT JOIN game_statusxp gs ON gs.game_title_id = ug.game_title_id 
    AND gs.platform_id = ug.platform_id 
    AND gs.user_id = ug.user_id
  LEFT JOIN game_totals gt ON gt.game_title_id = ug.game_title_id
    AND gt.platform_id = ug.platform_id
  LEFT JOIN games g ON g.platform_id = ug.platform_id
    AND (('x'::text || substr(md5((ug.platform_id::text || '_'::text) || g.platform_game_id), 1, 15)))::bit(60)::bigint = ug.game_title_id
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
