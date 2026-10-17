-- Dashboard-specific first page, preserving the full library's detailed fields.
-- Select 20 owned games before calculating their achievement aggregates.
-- Apply directly; do not push unrelated migrations.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE OR REPLACE FUNCTION public.get_dashboard_games(p_user_id uuid)
RETURNS TABLE(group_id text,name text,cover_url text,proxied_cover_url text,
 platforms jsonb[],total_statusxp numeric,avg_completion numeric,
 last_played_at timestamptz,game_title_ids bigint[])
LANGUAGE sql STABLE SET search_path='public','pg_temp' AS $$
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
  'completion',up.completion_percentage,'statusxp',ea.statusxp,
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
 )]::jsonb[],ea.statusxp,COALESCE(up.completion_percentage,0),
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
  COALESCE(sum(CASE WHEN a.include_in_score THEN a.base_status_xp*COALESCE(a.rarity_multiplier,1) ELSE 0 END),0)::integer::numeric statusxp,
  min(a.rarity_global) rarest_achievement_rarity,max(ua.earned_at) last_earned_at
 FROM public.user_achievement_unlocks ua
 JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 WHERE ua.user_id=p_user_id AND ua.platform_id=up.platform_id AND ua.platform_game_id=up.platform_game_id
) ea
WHERE up.user_id=p_user_id
ORDER BY COALESCE(ea.last_earned_at,up.last_played_at) DESC NULLS LAST,g.name;
$$;
REVOKE ALL ON FUNCTION public.get_dashboard_games(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_dashboard_games(uuid) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
