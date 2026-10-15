-- Set-based full refresh using the same scoring and rounding as the per-user calculator.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE OR REPLACE VIEW statusxp_private.statusxp_refresh_totals AS
WITH scored_games AS (
 SELECT ua.user_id,ua.platform_id,ua.platform_game_id,
 SUM(a.base_status_xp*COALESCE(a.rarity_multiplier,1.0))::integer earned_xp
 FROM public.user_achievements ua
 JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 JOIN public.games g USING(platform_id,platform_game_id)
 WHERE a.include_in_score=true
 GROUP BY ua.user_id,ua.platform_id,ua.platform_game_id
), scores AS (
 SELECT user_id,SUM(earned_xp)::bigint total_statusxp,COUNT(*)::integer total_game_entries
 FROM scored_games GROUP BY user_id
), possible_per_game AS MATERIALIZED (
 SELECT platform_id,platform_game_id,SUM(base_status_xp) potential
 FROM public.achievements WHERE include_in_score=true GROUP BY platform_id,platform_game_id
), potential AS (
 SELECT ug.user_id,SUM(g.potential)::bigint potential_statusxp
 FROM (SELECT DISTINCT user_id,platform_id,platform_game_id FROM public.user_achievements) ug
 JOIN possible_per_game g USING(platform_id,platform_game_id)
 GROUP BY ug.user_id
)
SELECT p.id user_id,s.total_statusxp,COALESCE(t.potential_statusxp,0)::bigint potential_statusxp,s.total_game_entries
FROM scores s JOIN public.profiles_private p ON p.id=s.user_id
LEFT JOIN potential t ON t.user_id=s.user_id
WHERE p.show_on_leaderboard=true AND p.merged_into_user_id IS NULL AND s.total_statusxp>0;
REVOKE ALL ON statusxp_private.statusxp_refresh_totals FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.refresh_statusxp_leaderboard()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path=''
SET work_mem='64MB'
SET enable_nestloop=off
SET enable_mergejoin=off
AS $$
BEGIN
 -- One source snapshot for the upsert and removal of stale/ineligible rows.
 WITH refreshed AS MATERIALIZED (SELECT * FROM statusxp_private.statusxp_refresh_totals),
 upserted AS (
  INSERT INTO public.leaderboard_cache(user_id,total_statusxp,potential_statusxp,total_game_entries,last_updated)
  SELECT user_id,total_statusxp,potential_statusxp,total_game_entries,now() FROM refreshed
  ON CONFLICT(user_id) DO UPDATE SET total_statusxp=EXCLUDED.total_statusxp,
   potential_statusxp=EXCLUDED.potential_statusxp,total_game_entries=EXCLUDED.total_game_entries,last_updated=EXCLUDED.last_updated
  RETURNING user_id
 )
 DELETE FROM public.leaderboard_cache lc
 WHERE NOT EXISTS(SELECT 1 FROM refreshed r WHERE r.user_id=lc.user_id);
END;
$$;
CREATE OR REPLACE FUNCTION public.refresh_statusxp_leaderboard_for_user(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

BEGIN

  -- First, check if user should be on leaderboard

  IF NOT EXISTS (

    SELECT 1 FROM profiles

    WHERE id = p_user_id

    AND show_on_leaderboard = true

    AND merged_into_user_id IS NULL

  ) THEN

    -- Remove them if they shouldn't be there

    DELETE FROM leaderboard_cache WHERE user_id = p_user_id;

    RETURN;

  END IF;



  -- Rest of the function unchanged...

  INSERT INTO public.leaderboard_cache (user_id, total_statusxp, potential_statusxp, total_game_entries, last_updated)

  SELECT

    p.id as user_id,

    COALESCE(game_totals.total_statusxp, 0) as total_statusxp,

    COALESCE(potential_totals.potential_statusxp, 0) as potential_statusxp,

    COALESCE(game_totals.total_games, 0) as total_game_entries,

    NOW() as last_updated

  FROM public.profiles p

  LEFT JOIN LATERAL (

    SELECT

      COUNT(*)::integer as total_games,

      COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp

    FROM public.calculate_statusxp_with_stacks(p.id)

  ) game_totals ON true

  LEFT JOIN LATERAL (

    SELECT

      COALESCE(SUM(a.base_status_xp), 0)::bigint as potential_statusxp

    FROM (

      SELECT DISTINCT platform_id, platform_game_id

      FROM user_achievements

      WHERE user_id = p.id

    ) user_games

    JOIN achievements a

      ON a.platform_id = user_games.platform_id

      AND a.platform_game_id = user_games.platform_game_id

    WHERE a.include_in_score = true

  ) potential_totals ON true

  WHERE p.id = p_user_id

    AND COALESCE(game_totals.total_statusxp, 0) > 0

  ON CONFLICT (user_id)

  DO UPDATE SET

    total_statusxp = EXCLUDED.total_statusxp,

    potential_statusxp = EXCLUDED.potential_statusxp,

    total_game_entries = EXCLUDED.total_game_entries,

    last_updated = EXCLUDED.last_updated;



  -- A zero source total must also remove an old positive cache row.
  IF NOT FOUND THEN
    DELETE FROM public.leaderboard_cache WHERE user_id=p_user_id;
  END IF;
END;
$function$
;
-- Xbox and Steam caches are regular views and have no refresh functions.
CREATE OR REPLACE FUNCTION public.auto_refresh_all_leaderboards()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.refresh_statusxp_leaderboard();
 PERFORM public.refresh_psn_leaderboard_cache();
END;
$$;
-- Maintenance operations are server-owned. Read-only leaderboard APIs stay public.
REVOKE EXECUTE ON FUNCTION public.refresh_statusxp_leaderboard(),
 public.refresh_statusxp_leaderboard_for_user(uuid),public.refresh_leaderboard_cache(),
 public.auto_refresh_all_leaderboards(),public.refresh_psn_leaderboard_cache()
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_statusxp_leaderboard(),
 public.refresh_statusxp_leaderboard_for_user(uuid),public.refresh_leaderboard_cache(),
 public.auto_refresh_all_leaderboards(),public.refresh_psn_leaderboard_cache()
 TO service_role;
COMMIT;
