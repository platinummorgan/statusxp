-- Make seasonal period RPCs execute as SECURITY DEFINER to avoid RLS-driven timeouts
-- for anon/authenticated callers on public leaderboard screens.
-- Safe for repeated execution; Supabase migration history ensures this runs once per DB.

BEGIN;

ALTER FUNCTION public.get_statusxp_period_leaderboard(text, integer, integer)
  SECURITY DEFINER;
ALTER FUNCTION public.get_statusxp_period_leaderboard(text, integer, integer)
  SET search_path = public;
REVOKE ALL ON FUNCTION public.get_statusxp_period_leaderboard(text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_statusxp_period_leaderboard(text, integer, integer)
  TO anon, authenticated, service_role;

ALTER FUNCTION public.get_psn_period_leaderboard(text, integer, integer)
  SECURITY DEFINER;
ALTER FUNCTION public.get_psn_period_leaderboard(text, integer, integer)
  SET search_path = public;
REVOKE ALL ON FUNCTION public.get_psn_period_leaderboard(text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_psn_period_leaderboard(text, integer, integer)
  TO anon, authenticated, service_role;

ALTER FUNCTION public.get_xbox_period_leaderboard(text, integer, integer)
  SECURITY DEFINER;
ALTER FUNCTION public.get_xbox_period_leaderboard(text, integer, integer)
  SET search_path = public;
REVOKE ALL ON FUNCTION public.get_xbox_period_leaderboard(text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_xbox_period_leaderboard(text, integer, integer)
  TO anon, authenticated, service_role;

ALTER FUNCTION public.get_steam_period_leaderboard(text, integer, integer)
  SECURITY DEFINER;
ALTER FUNCTION public.get_steam_period_leaderboard(text, integer, integer)
  SET search_path = public;
REVOKE ALL ON FUNCTION public.get_steam_period_leaderboard(text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_steam_period_leaderboard(text, integer, integer)
  TO anon, authenticated, service_role;

COMMIT;
