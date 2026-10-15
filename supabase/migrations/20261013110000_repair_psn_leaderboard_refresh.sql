-- Apply this repair directly to the linked production database; do not db push.
-- The covering indexes avoid repeated reads of wide achievement rows. Run the
-- concurrent index statements outside a transaction, then the atomic view swap.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_achievements_leaderboard_score_cover
 ON public.achievements(platform_id,platform_game_id,platform_achievement_id)
 INCLUDE (base_status_xp,rarity_multiplier) WHERE include_in_score=true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_achievements_psn_trophy_cover
 ON public.achievements(platform_id,platform_game_id,platform_achievement_id)
 INCLUDE(is_platinum,metadata)
 WHERE platform_id IN(1,2,5,9)
 AND (is_platinum OR metadata->>'psn_trophy_type' IN('bronze','silver','gold','platinum'));

BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
SET LOCAL work_mem='64MB';
SET LOCAL enable_nestloop=off;
SET LOCAL enable_mergejoin=off;

-- No CASCADE: unexpected dependents must abort the repair, not be removed.
DROP MATERIALIZED VIEW public.psn_leaderboard_cache;
CREATE MATERIALIZED VIEW public.psn_leaderboard_cache AS
WITH valid_definitions AS MATERIALIZED (
 SELECT platform_id,platform_game_id,platform_achievement_id,
 CASE WHEN is_platinum OR metadata->>'psn_trophy_type'='platinum' THEN 'platinum' ELSE metadata->>'psn_trophy_type' END trophy_type
 FROM public.achievements
 WHERE platform_id IN(1,2,5,9) AND (is_platinum OR metadata->>'psn_trophy_type' IN('bronze','silver','gold','platinum'))
), earned AS (
 SELECT ua.user_id,count(*) FILTER(WHERE a.trophy_type='bronze') bronze_count,
 count(*) FILTER(WHERE a.trophy_type='silver') silver_count,count(*) FILTER(WHERE a.trophy_type='gold') gold_count,
 count(*) FILTER(WHERE a.trophy_type='platinum') platinum_count,count(*) total_trophies,
 count(DISTINCT (ua.platform_id,ua.platform_game_id)) total_games
 FROM public.user_achievements ua JOIN valid_definitions a USING(platform_id,platform_game_id,platform_achievement_id)
 JOIN public.profiles p ON p.id=ua.user_id AND p.show_on_leaderboard AND p.merged_into_user_id IS NULL
 WHERE ua.platform_id IN(1,2,5,9) GROUP BY ua.user_id
), game_possible AS MATERIALIZED (
 SELECT platform_id,platform_game_id,count(*) FILTER(WHERE trophy_type='bronze') possible_bronze,
 count(*) FILTER(WHERE trophy_type='silver') possible_silver,count(*) FILTER(WHERE trophy_type='gold') possible_gold,
 count(*) FILTER(WHERE trophy_type='platinum') possible_platinum
 FROM valid_definitions GROUP BY platform_id,platform_game_id
), possible AS (
 SELECT ug.user_id,sum(g.possible_bronze)::bigint possible_bronze,sum(g.possible_silver)::bigint possible_silver,
 sum(g.possible_gold)::bigint possible_gold,sum(g.possible_platinum)::bigint possible_platinum
 FROM (SELECT DISTINCT user_id,platform_id,platform_game_id FROM public.user_achievements WHERE platform_id IN(1,2,5,9)) ug
 JOIN game_possible g USING(platform_id,platform_game_id) GROUP BY ug.user_id
)
SELECT e.user_id,COALESCE(p.psn_online_id,p.display_name,p.username,'Player') display_name,p.psn_avatar_url avatar_url,
 e.bronze_count,e.silver_count,e.gold_count,e.platinum_count,
 COALESCE(t.possible_bronze,0)::bigint possible_bronze,COALESCE(t.possible_silver,0)::bigint possible_silver,
 COALESCE(t.possible_gold,0)::bigint possible_gold,COALESCE(t.possible_platinum,0)::bigint possible_platinum,
 e.total_trophies,e.total_games,now() updated_at
 FROM earned e JOIN public.profiles p ON p.id=e.user_id LEFT JOIN possible t ON t.user_id=e.user_id
 WHERE e.total_trophies>0
 ORDER BY e.platinum_count DESC,e.gold_count DESC,e.silver_count DESC,e.bronze_count DESC,e.user_id;
CREATE UNIQUE INDEX idx_psn_leaderboard_cache_user_id ON public.psn_leaderboard_cache(user_id);
CREATE INDEX idx_psn_leaderboard_cache_platinum
 ON public.psn_leaderboard_cache(platinum_count DESC,gold_count DESC,silver_count DESC,bronze_count DESC);
GRANT SELECT ON public.psn_leaderboard_cache TO anon,authenticated,service_role;
COMMENT ON MATERIALIZED VIEW public.psn_leaderboard_cache IS
 'Recognized earned PSN trophies only; possible counts are aggregated once per platform/game. Refresh after sync and hourly.';

CREATE OR REPLACE FUNCTION public.refresh_psn_leaderboard_cache()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp
SET work_mem='64MB'
SET enable_nestloop=off
SET enable_mergejoin=off
AS $$
BEGIN
 REFRESH MATERIALIZED VIEW CONCURRENTLY public.psn_leaderboard_cache;
END;
$$;

-- Apply eligibility at read time as well, before ranking and pagination.
CREATE OR REPLACE FUNCTION public.get_psn_leaderboard_with_movement(limit_count integer DEFAULT 100, offset_count integer DEFAULT 0)
 RETURNS TABLE(user_id uuid, display_name text, avatar_url text, platinum_count bigint, gold_count bigint, silver_count bigint, bronze_count bigint, total_trophies bigint, total_games bigint, possible_platinum bigint, possible_gold bigint, possible_silver bigint, possible_bronze bigint, previous_rank integer, rank_change integer, is_new boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

BEGIN

  RETURN QUERY

  WITH current_leaderboard AS (

    SELECT

      lc.user_id,

      lc.display_name,

      lc.avatar_url,

      lc.platinum_count,

      lc.gold_count,

      lc.silver_count,

      lc.bronze_count,

      lc.total_trophies,

      lc.total_games,

      lc.possible_platinum,

      lc.possible_gold,

      lc.possible_silver,

      lc.possible_bronze,

      ROW_NUMBER() OVER (ORDER BY lc.platinum_count DESC, lc.gold_count DESC, lc.silver_count DESC, lc.bronze_count DESC, lc.user_id) as current_rank

    FROM public.psn_leaderboard_cache lc
    JOIN public.profiles p ON p.id=lc.user_id
    WHERE lc.total_trophies > 0
      AND lc.bronze_count+lc.silver_count+lc.gold_count+lc.platinum_count > 0
      AND p.show_on_leaderboard=true
      AND p.merged_into_user_id IS NULL

  ),

  latest_snapshot AS (

    SELECT DISTINCT ON (h.user_id)

      h.user_id,

      h.rank as prev_rank

    FROM psn_leaderboard_history h

    WHERE h.snapshot_at < now() - INTERVAL '1 hour'

    ORDER BY h.user_id, h.snapshot_at DESC

  )

  SELECT

    cl.user_id,

    cl.display_name,

    cl.avatar_url,

    cl.platinum_count,

    cl.gold_count,

    cl.silver_count,

    cl.bronze_count,

    cl.total_trophies,

    cl.total_games,

    cl.possible_platinum,

    cl.possible_gold,

    cl.possible_silver,

    cl.possible_bronze,

    ls.prev_rank as previous_rank,

    CASE

      WHEN ls.prev_rank IS NULL THEN 0

      ELSE (ls.prev_rank - cl.current_rank::integer)

    END as rank_change,

    (ls.prev_rank IS NULL) as is_new

  FROM current_leaderboard cl

  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id

  ORDER BY cl.current_rank

  LIMIT limit_count

  OFFSET offset_count;

END;

$function$
;
COMMIT;
