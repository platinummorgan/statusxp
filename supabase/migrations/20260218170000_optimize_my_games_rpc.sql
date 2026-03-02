-- Optimize My Games RPC to avoid hash-based joins and repeated correlated subqueries.
-- This reduces dashboard timeout risk as user libraries grow.

BEGIN;

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_platform_game_earned
ON public.user_achievements (user_id, platform_id, platform_game_id, earned_at DESC);

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
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
WITH user_games_base AS (
  SELECT
    up.user_id,
    up.platform_id,
    up.platform_game_id,
    ((('x'::text || substr(md5((up.platform_id::text || '_'::text) || up.platform_game_id), 1, 15)))::bit(60))::bigint AS game_title_id,
    g.name AS game_title,
    g.cover_url,
    up.achievements_earned::bigint AS earned_trophies,
    up.total_achievements::bigint AS total_trophies,
    up.completion_percentage AS completion_percent,
    up.last_played_at,
    up.current_score,
    p.code AS platform_code
  FROM public.user_progress up
  JOIN public.games g
    ON g.platform_id = up.platform_id
   AND g.platform_game_id = up.platform_game_id
  LEFT JOIN public.platforms p
    ON p.id = up.platform_id
  WHERE up.user_id = p_user_id
),
achievement_totals AS (
  SELECT
    a.platform_id,
    a.platform_game_id,
    COUNT(*)::bigint AS total_achievements,
    COALESCE(SUM(a.score_value), 0)::bigint AS total_score
  FROM public.achievements a
  GROUP BY a.platform_id, a.platform_game_id
),
earned_agg AS (
  SELECT
    ua.platform_id,
    ua.platform_game_id,
    COUNT(*) FILTER (WHERE a.metadata ->> 'psn_trophy_type' = 'bronze')::bigint AS bronze_trophies,
    COUNT(*) FILTER (WHERE a.metadata ->> 'psn_trophy_type' = 'silver')::bigint AS silver_trophies,
    COUNT(*) FILTER (WHERE a.metadata ->> 'psn_trophy_type' = 'gold')::bigint AS gold_trophies,
    COUNT(*) FILTER (WHERE a.metadata ->> 'psn_trophy_type' = 'platinum')::bigint AS platinum_trophies,
    COALESCE(
      SUM(
        CASE
          WHEN a.include_in_score THEN a.base_status_xp
          ELSE 0
        END
      ),
      0
    )::numeric AS statusxp,
    MIN(a.rarity_global) AS rarest_achievement_rarity,
    MAX(ua.earned_at) AS last_earned_at
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
  GROUP BY ua.platform_id, ua.platform_game_id
)
SELECT
  ('group_' || ugb.game_title_id::text) AS group_id,
  ugb.game_title AS name,
  ugb.cover_url,
  CASE
    WHEN ugb.cover_url LIKE '%cloudfront%' OR ugb.cover_url LIKE '%supabase%'
      THEN ugb.cover_url
    ELSE NULL
  END AS proxied_cover_url,
  ARRAY[
    jsonb_build_object(
      'code', LOWER(
        CASE
          WHEN ugb.platform_code IN ('PS3', 'PS4', 'PS5', 'PSVITA') THEN 'psn'
          WHEN ugb.platform_code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX', 'Xbox') THEN 'xbox'
          WHEN ugb.platform_code = 'Steam' THEN 'steam'
          ELSE 'unknown'
        END
      ),
      'completion', ugb.completion_percent,
      'statusxp', COALESCE(ea.statusxp, 0),
      'game_title_id', ugb.game_title_id,
      'earned_trophies', ugb.earned_trophies,
      'total_trophies', COALESCE(at.total_achievements, ugb.total_trophies),
      'bronze_trophies', COALESCE(ea.bronze_trophies, 0),
      'silver_trophies', COALESCE(ea.silver_trophies, 0),
      'gold_trophies', COALESCE(ea.gold_trophies, 0),
      'platinum_trophies', COALESCE(ea.platinum_trophies, 0),
      'xbox_achievements_earned', ugb.earned_trophies,
      'xbox_total_achievements', COALESCE(at.total_achievements, ugb.total_trophies),
      'platform_id', ugb.platform_id,
      'platform_game_id', ugb.platform_game_id,
      'current_score', COALESCE(ugb.current_score, 0),
      'total_score', COALESCE(at.total_score, 0),
      'rarest_achievement_rarity', ea.rarest_achievement_rarity,
      'last_played_at', ugb.last_played_at,
      'last_trophy_earned_at', COALESCE(ea.last_earned_at, ugb.last_played_at)
    )
  ]::jsonb[] AS platforms,
  COALESCE(ea.statusxp, 0) AS total_statusxp,
  COALESCE(ugb.completion_percent, 0) AS avg_completion,
  COALESCE(ea.last_earned_at, ugb.last_played_at) AS last_played_at,
  ARRAY[ugb.game_title_id] AS game_title_ids
FROM user_games_base ugb
LEFT JOIN earned_agg ea
  ON ea.platform_id = ugb.platform_id
 AND ea.platform_game_id = ugb.platform_game_id
LEFT JOIN achievement_totals at
  ON at.platform_id = ugb.platform_id
 AND at.platform_game_id = ugb.platform_game_id
ORDER BY COALESCE(ea.last_earned_at, ugb.last_played_at) DESC NULLS LAST, ugb.game_title;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_grouped_games(uuid) TO anon, authenticated, service_role;

COMMIT;
