-- Migration: Filter zero StatusXP users from leaderboard_cache
-- Date: 2026-01-25

BEGIN;

CREATE OR REPLACE FUNCTION public.refresh_statusxp_leaderboard()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
  SELECT 
    p.id as user_id,
    COALESCE(game_totals.total_statusxp, 0) as total_statusxp,
    COALESCE(game_totals.total_games, 0) as total_game_entries,
    NOW() as last_updated
  FROM public.profiles p
  LEFT JOIN LATERAL (
    SELECT 
      COUNT(*)::integer as total_games,
      COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp
    FROM public.calculate_statusxp_with_stacks(p.id)
  ) game_totals ON true
  WHERE p.show_on_leaderboard = true
    AND p.merged_into_user_id IS NULL
    AND COALESCE(game_totals.total_statusxp, 0) > 0
  ON CONFLICT (user_id) 
  DO UPDATE SET
    total_statusxp = EXCLUDED.total_statusxp,
    total_game_entries = EXCLUDED.total_game_entries,
    last_updated = EXCLUDED.last_updated;
END;
$$;

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
  LEFT JOIN LATERAL (
    SELECT 
      COUNT(*)::integer as total_games,
      COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp
    FROM public.calculate_statusxp_with_stacks(p.id)
  ) game_totals ON true
  WHERE p.id = p_user_id
    AND p.show_on_leaderboard = true
    AND p.merged_into_user_id IS NULL
    AND COALESCE(game_totals.total_statusxp, 0) > 0
  ON CONFLICT (user_id) 
  DO UPDATE SET
    total_statusxp = EXCLUDED.total_statusxp,
    total_game_entries = EXCLUDED.total_game_entries,
    last_updated = EXCLUDED.last_updated;

  -- If user has zero StatusXP, ensure they are removed
  DELETE FROM leaderboard_cache
  WHERE user_id = p_user_id
    AND COALESCE(total_statusxp, 0) = 0;
END;
$$;

COMMIT;
