-- Keep large Flex Room/game-history reads within the normal app timeout.
-- One aggregate pass for game definitions + earned rows; plan for the actual
-- library size via a parameterized query rather than reusing a tiny-user plan.
-- Existing public visibility checks and invoker RLS remain unchanged.
BEGIN;
SET LOCAL lock_timeout='3s';
ALTER TABLE public.achievements SET(autovacuum_vacuum_scale_factor=0.02,autovacuum_analyze_scale_factor=0.02);
ALTER TABLE public.user_achievements SET(autovacuum_vacuum_scale_factor=0.02,autovacuum_analyze_scale_factor=0.02);
CREATE OR REPLACE FUNCTION public.get_user_grouped_games(p_user_id uuid)
 RETURNS TABLE(group_id text, name text, cover_url text, proxied_cover_url text, platforms jsonb[], total_statusxp numeric, avg_completion numeric, last_played_at timestamp with time zone, game_title_ids bigint[])
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE library_sql text;
BEGIN
 -- Covering indexes keep both large and small collections on indexed facts.
 library_sql := $library$
WITH library_definitions AS NOT MATERIALIZED (
 SELECT a.platform_id,a.platform_game_id,a.platform_achievement_id,a.score_value,
  a.base_status_xp,a.rarity_multiplier,a.rarity_global,a.include_in_score
 FROM public.achievements a
), user_unlocks AS MATERIALIZED (SELECT user_id,platform_id,platform_game_id,platform_achievement_id,earned_at FROM public.user_achievement_unlocks WHERE user_id=$1), user_games_base AS MATERIALIZED (
  SELECT
    up.platform_id,
    up.platform_game_id,
    ((('x' || substr(md5(up.platform_id::text || '_' || up.platform_game_id), 1, 15))::bit(60))::bigint) AS game_title_id,
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
  LEFT JOIN public.platforms p ON p.id = up.platform_id
  WHERE up.user_id = $1
),
trophy_types AS MATERIALIZED (
SELECT 'bronze'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='bronze'
UNION ALL
SELECT 'silver'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='silver'
UNION ALL
SELECT 'gold'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='gold'
UNION ALL
SELECT 'platinum'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='platinum'
), trophy_counts AS (
 SELECT ua.platform_id,ua.platform_game_id,
 count(*) FILTER(WHERE t.trophy_type='bronze')::bigint AS bronze_trophies,
 count(*) FILTER(WHERE t.trophy_type='silver')::bigint AS silver_trophies,
 count(*) FILTER(WHERE t.trophy_type='gold')::bigint AS gold_trophies,
 count(*) FILTER(WHERE t.trophy_type='platinum')::bigint AS platinum_trophies
 FROM user_unlocks ua JOIN trophy_types t USING(platform_id,platform_game_id,platform_achievement_id)
 GROUP BY ua.platform_id,ua.platform_game_id
),
game_stats AS MATERIALIZED (
 SELECT a.platform_id,a.platform_game_id,
  count(*)::bigint AS total_achievements,
  coalesce(sum(a.score_value),0)::bigint AS total_score,
  coalesce(sum(CASE WHEN ua.platform_achievement_id IS NOT NULL AND a.include_in_score THEN a.base_status_xp*coalesce(a.rarity_multiplier,1.0) ELSE 0 END),0)::integer::numeric AS statusxp,
  min(a.rarity_global) FILTER(WHERE ua.platform_achievement_id IS NOT NULL) AS rarest_achievement_rarity,
  max(ua.earned_at) AS last_earned_at
 FROM user_games_base ugb
 JOIN library_definitions a ON a.platform_id=ugb.platform_id AND a.platform_game_id=ugb.platform_game_id
 LEFT JOIN user_unlocks ua ON ua.platform_id=a.platform_id AND ua.platform_game_id=a.platform_game_id AND ua.platform_achievement_id=a.platform_achievement_id
 GROUP BY a.platform_id,a.platform_game_id
)
SELECT
  'group_' || ugb.game_title_id::text,
  ugb.game_title,
  ugb.cover_url,
  CASE
    WHEN ugb.cover_url LIKE '%cloudfront%' OR ugb.cover_url LIKE '%supabase%'
      THEN ugb.cover_url
    ELSE NULL
  END,
  ARRAY[
    jsonb_build_object(
      'code', LOWER(CASE
        WHEN ugb.platform_code IN ('PS3', 'PS4', 'PS5', 'PSVITA') THEN 'psn'
        WHEN ugb.platform_code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX', 'Xbox') THEN 'xbox'
        WHEN ugb.platform_code = 'Steam' THEN 'steam'
        ELSE 'unknown'
      END),
      'completion', ugb.completion_percent,
      'statusxp', COALESCE(ea.statusxp, 0),
      'game_title_id', ugb.game_title_id,
      'earned_trophies', ugb.earned_trophies,
      'total_trophies', COALESCE(ea.total_achievements, ugb.total_trophies),
      'bronze_trophies', COALESCE(tc.bronze_trophies, 0),
      'silver_trophies', COALESCE(tc.silver_trophies, 0),
      'gold_trophies', COALESCE(tc.gold_trophies, 0),
      'platinum_trophies', COALESCE(tc.platinum_trophies, 0),
      'xbox_achievements_earned', ugb.earned_trophies,
      'xbox_total_achievements', COALESCE(ea.total_achievements, ugb.total_trophies),
      'platform_id', ugb.platform_id,
      'platform_game_id', ugb.platform_game_id,
      'current_score', COALESCE(ugb.current_score, 0),
      'total_score', COALESCE(ea.total_score, 0),
      'rarest_achievement_rarity', ea.rarest_achievement_rarity,
      'last_played_at', ugb.last_played_at,
      'last_trophy_earned_at', ea.last_earned_at
    )
  ]::jsonb[],
  COALESCE(ea.statusxp, 0),
  COALESCE(ugb.completion_percent, 0),
  COALESCE(ea.last_earned_at, ugb.last_played_at),
  ARRAY[ugb.game_title_id]
FROM user_games_base ugb
LEFT JOIN trophy_counts tc ON tc.platform_id=ugb.platform_id AND tc.platform_game_id=ugb.platform_game_id
LEFT JOIN game_stats ea ON ea.platform_id=ugb.platform_id AND ea.platform_game_id=ugb.platform_game_id
ORDER BY COALESCE(ea.last_earned_at, ugb.last_played_at) DESC NULLS LAST,
         ugb.game_title;
$library$;
 RETURN QUERY EXECUTE library_sql USING p_user_id;
END;
$function$;
CREATE OR REPLACE FUNCTION public.get_most_time_sunk_game_v2(p_user_id uuid)
 RETURNS TABLE(platform_id bigint, platform_game_id text, platform_achievement_id text, earned_at timestamp with time zone, rarity_global numeric, achievement_name text, achievement_icon_url text, game_name text, game_cover_url text)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 RETURN QUERY
 WITH counts AS MATERIALIZED (
  SELECT ua.platform_id,ua.platform_game_id,count(*) AS earned_count
  FROM public.user_achievements ua
  WHERE ua.user_id=p_user_id AND ua.earned_at IS NOT NULL
  GROUP BY ua.platform_id,ua.platform_game_id
 ), owned AS MATERIALIZED (
  SELECT c.*,g.name AS game_name,g.cover_url
  FROM counts c JOIN public.games g USING(platform_id,platform_game_id)
 ), candidates AS MATERIALIZED (
  SELECT o.* FROM owned o WHERE o.earned_count=(SELECT max(m.earned_count) FROM owned m)
 ), best_game AS (
  SELECT c.* FROM candidates c
  ORDER BY (SELECT count(*) FROM public.achievements a2 WHERE a2.platform_id=c.platform_id AND a2.platform_game_id=c.platform_game_id) DESC,c.platform_id,c.platform_game_id
  LIMIT 1
 )
 SELECT ua.platform_id,ua.platform_game_id,ua.platform_achievement_id,ua.earned_at,
  a.rarity_global,a.name,coalesce(a.proxied_icon_url,a.icon_url),bg.game_name,bg.cover_url
 FROM best_game bg
 JOIN public.user_achievements ua ON ua.user_id=p_user_id AND ua.platform_id=bg.platform_id AND ua.platform_game_id=bg.platform_game_id
 JOIN public.achievements a ON a.platform_id=ua.platform_id AND a.platform_game_id=ua.platform_game_id AND a.platform_achievement_id=ua.platform_achievement_id
 WHERE ua.earned_at IS NOT NULL
 ORDER BY ua.earned_at DESC,ua.platform_achievement_id
 LIMIT 1;
END;
$function$;
NOTIFY pgrst,'reload schema';
COMMIT;
