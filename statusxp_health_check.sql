-- StatusXP Health Check & Fix Plan
-- Run in Supabase SQL editor. Safe read-only diagnostics first, then optional fixes.

-- =====================================
-- 0) Confirm canonical sources
-- =====================================
-- Canonical calc: calculate_statusxp_with_stacks
-- Canonical totals: leaderboard_cache (table)

-- 1) Inspect tables/views that might conflict
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'leaderboard_cache',
    'leaderboard_global_cache',
    'user_statusxp_scores',
    'user_statusxp_totals',
    'user_statusxp_summary',
    'user_games',
    'user_progress'
  )
ORDER BY table_name;

-- 2) Inspect functions related to StatusXP
SELECT n.nspname as schema, p.proname as function, pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'calculate_statusxp_with_stacks',
    'refresh_statusxp_leaderboard',
    'refresh_statusxp_leaderboard_for_user',
    'refresh_leaderboard_cache',
    'calculate_statusxp_simple',
    'calculate_user_game_statusxp',
    'calculate_user_achievement_statusxp'
  );

-- 3) Inspect triggers that might write leaderboard_cache
SELECT event_object_table as table_name, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN ('user_achievements', 'user_progress');

-- 4) Check leaderboard_cache freshness
SELECT
  COUNT(*) as rows,
  MIN(last_updated) as oldest,
  MAX(last_updated) as newest
FROM leaderboard_cache;

-- 5) Compare leaderboard_cache vs raw calculation for a sample user
-- Replace username if needed
WITH target_user AS (
  SELECT id FROM profiles WHERE username = 'fdymf45xbw'
),
raw_total AS (
  SELECT COALESCE(SUM(statusxp_effective), 0) as total
  FROM calculate_statusxp_with_stacks((SELECT id FROM target_user))
),
cache_total AS (
  SELECT total_statusxp as total
  FROM leaderboard_cache
  WHERE user_id = (SELECT id FROM target_user)
)
SELECT
  (SELECT total FROM raw_total) as raw_total,
  (SELECT total FROM cache_total) as cache_total;

-- =====================================
-- OPTIONAL FIXES (run only if diagnostics show problems)
-- =====================================

-- A) Ensure leaderboard_cache is a TABLE (not a view)
-- If table_type shows VIEW for leaderboard_cache, drop and recreate.
-- DROP VIEW IF EXISTS leaderboard_cache CASCADE;
-- CREATE TABLE IF NOT EXISTS public.leaderboard_cache (
--   user_id uuid PRIMARY KEY REFERENCES public.profiles(id),
--   total_statusxp bigint NOT NULL DEFAULT 0,
--   total_game_entries integer NOT NULL DEFAULT 0,
--   last_updated timestamptz DEFAULT now()
-- );
-- CREATE INDEX IF NOT EXISTS idx_leaderboard_cache_statusxp
--   ON public.leaderboard_cache(total_statusxp DESC);

-- B) Rebuild StatusXP leaderboard using canonical function
-- TRUNCATE public.leaderboard_cache;
-- INSERT INTO public.leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
-- SELECT
--   p.id as user_id,
--   COALESCE(game_totals.total_statusxp, 0) as total_statusxp,
--   COALESCE(game_totals.total_games, 0) as total_game_entries,
--   NOW() as last_updated
-- FROM public.profiles p
-- LEFT JOIN LATERAL (
--   SELECT COUNT(*)::integer as total_games,
--          COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp
--   FROM public.calculate_statusxp_with_stacks(p.id)
-- ) game_totals ON true
-- WHERE p.show_on_leaderboard = true
--   AND p.merged_into_user_id IS NULL;

-- C) Re-attach trigger to user_achievements to keep cache fresh
-- This uses the per-user refresh to avoid timeouts.
-- CREATE OR REPLACE FUNCTION public.update_leaderboard_on_achievements_change()
-- RETURNS TRIGGER AS $$
-- BEGIN
--   IF (TG_OP = 'DELETE') THEN
--     PERFORM public.refresh_statusxp_leaderboard_for_user(OLD.user_id);
--   ELSE
--     PERFORM public.refresh_statusxp_leaderboard_for_user(NEW.user_id);
--   END IF;
--   RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- DROP TRIGGER IF EXISTS trg_refresh_leaderboard_on_achievements ON public.user_achievements;
-- CREATE TRIGGER trg_refresh_leaderboard_on_achievements
-- AFTER INSERT OR UPDATE OR DELETE ON public.user_achievements
-- FOR EACH ROW EXECUTE FUNCTION public.update_leaderboard_on_achievements_change();
