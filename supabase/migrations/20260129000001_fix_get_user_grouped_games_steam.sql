-- Fix get_user_grouped_games to properly include Steam games
-- Issue: Complex hash-based JOIN was failing for Steam games
-- Solution: Simplify to direct JOIN on platform_id and platform_game_id

CREATE OR REPLACE FUNCTION public.get_user_grouped_games(p_user_id uuid)
RETURNS TABLE(
  group_id text,
  name text,
  cover_url text,
  proxied_cover_url text,
  platforms jsonb[],
  total_statusxp numeric,
  avg_completion numeric,
  last_played_at timestamptz,
  game_title_ids bigint[]
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
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
      'statusxp', 0,
      'game_title_id', ug.game_title_id,
      'earned_trophies', ug.earned_trophies,
      'total_trophies', ug.total_trophies,
      'bronze_trophies', ug.bronze_trophies,
      'silver_trophies', ug.silver_trophies,
      'gold_trophies', ug.gold_trophies,
      'platinum_trophies', ug.platinum_trophies,
      'xbox_achievements_earned', ug.earned_trophies,
      'xbox_total_achievements', ug.total_trophies,
      'platform_id', ug.platform_id,
      'platform_game_id', (
        -- Extract platform_game_id from user_progress since user_games doesn't store it
        SELECT up.platform_game_id 
        FROM user_progress up 
        WHERE up.user_id = ug.user_id 
          AND up.platform_id = ug.platform_id
          AND (('x'::text || substr(md5((up.platform_id::text || '_'::text) || up.platform_game_id), 1, 15)))::bit(60)::bigint = ug.game_title_id
        LIMIT 1
      ),
      'current_score', ug.current_score,
      'total_score', 0
    )] as platforms,
    0::NUMERIC as total_statusxp,
    COALESCE(ug.completion_percent, 0) as avg_completion,
    COALESCE(
      CASE WHEN ug.platform_id = 1 THEN ug.last_trophy_earned_at ELSE NULL END,
      ug.last_played_at
    ) as last_played_at,
    ARRAY[ug.game_title_id] as game_title_ids
  FROM user_games ug
  -- Direct JOIN to games using platform_id from user_games
  -- Get platform_game_id from a subquery to user_progress
  LEFT JOIN LATERAL (
    SELECT up.platform_game_id
    FROM user_progress up
    WHERE up.user_id = ug.user_id
      AND up.platform_id = ug.platform_id
      AND (('x'::text || substr(md5((up.platform_id::text || '_'::text) || up.platform_game_id), 1, 15)))::bit(60)::bigint = ug.game_title_id
    LIMIT 1
  ) up_data ON true
  LEFT JOIN games g ON g.platform_id = ug.platform_id 
    AND g.platform_game_id = up_data.platform_game_id
  LEFT JOIN platforms p ON p.id = ug.platform_id
  WHERE ug.user_id = p_user_id
  ORDER BY 
    COALESCE(
      CASE WHEN ug.platform_id = 1 THEN ug.last_trophy_earned_at ELSE NULL END,
      ug.last_played_at
    ) DESC NULLS LAST,
    ug.game_title;
END;
$$;

COMMENT ON FUNCTION public.get_user_grouped_games(uuid) IS 
'Returns user games grouped for display. Fixed to properly include Steam games by using LATERAL subquery for platform_game_id lookup.';
