-- Migration: Refresh StatusXP leaderboard per user to avoid timeouts
-- Date: 2026-01-25

BEGIN;
-- Refresh leaderboard for a single user
CREATE OR REPLACE FUNCTION public.refresh_statusxp_leaderboard_for_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
  SELECT 
    p.id as user_id,
    COALESCE(game_totals.total_statusxp, 0) as total_statusxp,
    COALESCE(game_totals.total_games, 0) as total_game_entries,
    NOW() as last_updated
  FROM public.profiles p
  LEFT JOIN (
    SELECT 
      ua.user_id,
      COUNT(DISTINCT (ua.platform_id, ua.platform_game_id)) as total_games,
      SUM(statusxp_effective) as total_statusxp
    FROM public.user_achievements ua
    JOIN LATERAL (
      SELECT statusxp_effective
      FROM public.calculate_statusxp_with_stacks(ua.user_id)
      WHERE platform_id = ua.platform_id
        AND platform_game_id = ua.platform_game_id
      LIMIT 1
    ) calc ON true
    WHERE ua.user_id = p_user_id
    GROUP BY ua.user_id
  ) game_totals ON game_totals.user_id = p.id
  WHERE p.id = p_user_id
    AND p.show_on_leaderboard = true
    AND p.merged_into_user_id IS NULL
  ON CONFLICT (user_id) 
  DO UPDATE SET
    total_statusxp = EXCLUDED.total_statusxp,
    total_game_entries = EXCLUDED.total_game_entries,
    last_updated = EXCLUDED.last_updated;
END;
$$;
-- Trigger function to refresh for the affected user only
CREATE OR REPLACE FUNCTION public.update_leaderboard_on_achievements_change()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM public.refresh_statusxp_leaderboard_for_user(OLD.user_id);
  ELSE
    PERFORM public.refresh_statusxp_leaderboard_for_user(NEW.user_id);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
-- Replace statement trigger with row-level trigger
DROP TRIGGER IF EXISTS trigger_update_leaderboard_on_achievements ON public.user_achievements;
CREATE TRIGGER trigger_update_leaderboard_on_achievements
AFTER INSERT OR UPDATE OR DELETE ON public.user_achievements
FOR EACH ROW
EXECUTE FUNCTION public.update_leaderboard_on_achievements_change();
COMMIT;
