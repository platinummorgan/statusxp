-- Migration: Fix leaderboard refresh to avoid safeupdate DELETE errors
-- Date: 2026-01-25

BEGIN;
-- Replace DELETE with TRUNCATE and run as definer for safety
CREATE OR REPLACE FUNCTION public.refresh_leaderboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  TRUNCATE TABLE public.leaderboard_cache;

  INSERT INTO public.leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
  SELECT 
    up.user_id,
    SUM(up.current_score)::bigint as total_statusxp,
    COUNT(DISTINCT up.platform_game_id) as total_game_entries,
    NOW() as last_updated
  FROM public.user_progress up
  WHERE up.current_score > 0
  GROUP BY up.user_id;
END;
$$;
COMMIT;
