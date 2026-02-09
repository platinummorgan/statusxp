-- Migration: Use statusxp calculation source for leaderboard refresh
-- Date: 2026-01-25

BEGIN;
-- Ensure refresh_leaderboard_cache uses the same source as refresh_statusxp_leaderboard
CREATE OR REPLACE FUNCTION public.refresh_leaderboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Delegate to the canonical StatusXP refresh (uses user_achievements + calculate_statusxp_with_stacks)
  PERFORM public.refresh_statusxp_leaderboard();
END;
$$;
-- Update trigger to call refresh_leaderboard_cache (now delegates to refresh_statusxp_leaderboard)
CREATE OR REPLACE FUNCTION public.update_leaderboard_on_progress_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.refresh_leaderboard_cache();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Refresh leaderboards whenever achievements are written (any platform sync)
CREATE OR REPLACE FUNCTION public.update_leaderboard_on_achievements_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.refresh_leaderboard_cache();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Update auto-refresh helper to use the new refresh strategy
CREATE OR REPLACE FUNCTION public.auto_refresh_all_leaderboards()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- StatusXP (table) refresh
  PERFORM public.refresh_leaderboard_cache();

  -- Platform leaderboards are views and stay current automatically
  PERFORM public.refresh_psn_leaderboard_cache();
  PERFORM public.refresh_xbox_leaderboard_cache();
  PERFORM public.refresh_steam_leaderboard_cache();
END;
$$;
-- Drop old trigger(s) if they exist
DROP TRIGGER IF EXISTS trigger_update_leaderboard_on_achievements ON public.user_achievements;
-- Create new trigger - fires after INSERT/UPDATE/DELETE on user_achievements
CREATE TRIGGER trigger_update_leaderboard_on_achievements
AFTER INSERT OR UPDATE OR DELETE ON public.user_achievements
FOR EACH STATEMENT
EXECUTE FUNCTION public.update_leaderboard_on_achievements_change();
COMMIT;
