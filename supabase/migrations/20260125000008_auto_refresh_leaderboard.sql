-- Migration: Make leaderboard cache auto-refresh when user_progress changes
-- Date: 2026-01-25

BEGIN;

-- 1. Update the refresh function to properly populate the table
CREATE OR REPLACE FUNCTION public.refresh_leaderboard_cache()
RETURNS void AS $$
BEGIN
  DELETE FROM public.leaderboard_cache;
  
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
$$ LANGUAGE plpgsql;

-- 2. Create trigger to auto-refresh leaderboard when user_progress changes
CREATE OR REPLACE FUNCTION public.update_leaderboard_on_progress_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Refresh the entire leaderboard cache (could be optimized to just update one user)
  PERFORM public.refresh_leaderboard_cache();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop old trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_leaderboard_on_progress ON public.user_progress;

-- Create new trigger - fires after INSERT, UPDATE on user_progress
CREATE TRIGGER trigger_update_leaderboard_on_progress
AFTER INSERT OR UPDATE ON public.user_progress
FOR EACH STATEMENT
EXECUTE FUNCTION public.update_leaderboard_on_progress_change();

COMMIT;
