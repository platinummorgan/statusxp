BEGIN;
SET LOCAL lock_timeout='5s';
-- Add the completion award before the existing per-game integer rounding.
CREATE OR REPLACE FUNCTION public.get_dashboard_games(p_user_id uuid)
 RETURNS TABLE(group_id text, name text, cover_url text, proxied_cover_url text, platforms jsonb[], total_statusxp numeric, avg_completion numeric, last_played_at timestamp with time zone, game_title_ids bigint[])
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
WITH selected_games AS MATERIALIZED (
 SELECT up.* FROM public.user_progress up
 JOIN public.games g USING(platform_id,platform_game_id)
 WHERE up.user_id=p_user_id AND (p_user_id=auth.uid() OR auth.role()='service_role')
 ORDER BY COALESCE(up.last_achievement_earned_at,up.last_played_at) DESC NULLS LAST,g.name,up.platform_id,up.platform_game_id
 LIMIT 20
)
SELECT 'group_'||identity.game_title_id::text,g.name,g.cover_url,
 CASE WHEN g.cover_url LIKE '%cloudfront%' OR g.cover_url LIKE '%supabase%' THEN g.cover_url ELSE NULL END,
 ARRAY[jsonb_build_object(
  'code',lower(CASE WHEN p.code IN('PS3','PS4','PS5','PSVITA') THEN 'psn'
   WHEN p.code IN('XBOX360','XBOXONE','XBOXSERIESX','Xbox') THEN 'xbox'
   WHEN p.code='Steam' THEN 'steam' ELSE 'unknown' END),
  'completion',up.completion_percentage,'statusxp',(ea.statusxp+COALESCE(mythic.base_status_xp,0))::integer::numeric,
  'game_title_id',identity.game_title_id,'earned_trophies',up.achievements_earned,
  'total_trophies',CASE WHEN totals.total_achievements>0 THEN totals.total_achievements ELSE up.total_achievements END,
  'bronze_trophies',ea.bronze_trophies,'silver_trophies',ea.silver_trophies,
  'gold_trophies',ea.gold_trophies,'platinum_trophies',ea.platinum_trophies,
  'xbox_achievements_earned',up.achievements_earned,
  'xbox_total_achievements',CASE WHEN totals.total_achievements>0 THEN totals.total_achievements ELSE up.total_achievements END,
  'platform_id',up.platform_id,'platform_game_id',up.platform_game_id,
  'current_score',COALESCE(up.current_score,0),'total_score',totals.total_score,
  'rarest_achievement_rarity',ea.rarest_achievement_rarity,'last_played_at',up.last_played_at,
  'last_trophy_earned_at',ea.last_earned_at
 )]::jsonb[],(ea.statusxp+COALESCE(mythic.base_status_xp,0))::integer::numeric,COALESCE(up.completion_percentage,0),
 COALESCE(ea.last_earned_at,up.last_played_at),ARRAY[identity.game_title_id]
FROM selected_games up
JOIN public.games g ON g.platform_id=up.platform_id AND g.platform_game_id=up.platform_game_id
LEFT JOIN public.platforms p ON p.id=up.platform_id
CROSS JOIN LATERAL (
 SELECT ((('x'||substr(md5(up.platform_id::text||'_'||up.platform_game_id),1,15))::bit(60))::bigint) game_title_id
) identity
CROSS JOIN LATERAL (
 SELECT count(*)::bigint total_achievements,COALESCE(sum(a.score_value),0)::bigint total_score
 FROM public.achievements a
 WHERE a.platform_id=up.platform_id AND a.platform_game_id=up.platform_game_id
) totals
CROSS JOIN LATERAL (
 SELECT count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='bronze')::bigint bronze_trophies,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='silver')::bigint silver_trophies,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='gold')::bigint gold_trophies,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='platinum')::bigint platinum_trophies,
  COALESCE(sum(CASE WHEN a.include_in_score THEN a.base_status_xp*COALESCE(a.rarity_multiplier,1) ELSE 0 END),0)::numeric statusxp,
  min(a.rarity_global) rarest_achievement_rarity,max(ua.earned_at) last_earned_at
 FROM public.user_achievement_unlocks ua
 JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 WHERE ua.user_id=p_user_id AND ua.platform_id=up.platform_id AND ua.platform_game_id=up.platform_game_id
) ea
LEFT JOIN public.xbox_mythic_awards mythic ON mythic.user_id=p_user_id AND mythic.platform_id=up.platform_id AND mythic.platform_game_id=up.platform_game_id
WHERE up.user_id=p_user_id
ORDER BY COALESCE(ea.last_earned_at,up.last_played_at) DESC NULLS LAST,g.name;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_grouped_games(p_user_id uuid)
 RETURNS TABLE(group_id text, name text, cover_url text, proxied_cover_url text, platforms jsonb[], total_statusxp numeric, avg_completion numeric, last_played_at timestamp with time zone, game_title_ids bigint[])
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '15s'
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
  coalesce(sum(CASE WHEN ua.platform_achievement_id IS NOT NULL AND a.include_in_score THEN a.base_status_xp*coalesce(a.rarity_multiplier,1.0) ELSE 0 END),0)::numeric AS statusxp,
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
      'statusxp', (COALESCE(ea.statusxp, 0)+COALESCE(mythic.base_status_xp,0))::integer::numeric,
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
  (COALESCE(ea.statusxp, 0)+COALESCE(mythic.base_status_xp,0))::integer::numeric,
  COALESCE(ugb.completion_percent, 0),
  COALESCE(ea.last_earned_at, ugb.last_played_at),
  ARRAY[ugb.game_title_id]
FROM user_games_base ugb
LEFT JOIN trophy_counts tc ON tc.platform_id=ugb.platform_id AND tc.platform_game_id=ugb.platform_game_id
LEFT JOIN game_stats ea ON ea.platform_id=ugb.platform_id AND ea.platform_game_id=ugb.platform_game_id
LEFT JOIN public.xbox_mythic_awards mythic ON mythic.user_id=$1 AND mythic.platform_id=ugb.platform_id AND mythic.platform_game_id=ugb.platform_game_id
ORDER BY COALESCE(ea.last_earned_at, ugb.last_played_at) DESC NULLS LAST,
         ugb.game_title;
$library$;
 RETURN QUERY EXECUTE library_sql USING p_user_id;
END;
$function$;
COMMIT;
