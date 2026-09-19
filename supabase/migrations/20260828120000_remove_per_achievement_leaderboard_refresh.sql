-- Stop recalculating leaderboard caches for every achievement row written.
--
-- Each production sync explicitly calls refresh_statusxp_leaderboard_for_user()
-- once after it finishes writing a user's achievements. Keeping any of these
-- triggers enabled makes a batch upsert recalculate the same user's complete
-- score once per row and can produce quadratic database work.
--
-- This migration is intentionally idempotent because production migrations are
-- currently applied manually through the Supabase SQL Editor.

BEGIN;

-- Current row-level trigger introduced by
-- 20260125000012_refresh_statusxp_single_user.sql.
DROP TRIGGER IF EXISTS trigger_update_leaderboard_on_achievements
  ON public.user_achievements;

-- Legacy trigger name used by the original platform leaderboard cache design.
-- Drop it as well in case it still exists in production schema history.
DROP TRIGGER IF EXISTS refresh_leaderboards_after_achievement_sync
  ON public.user_achievements;

-- Older migrations refreshed the complete leaderboard after changes to
-- user_progress. user_achievements is now the StatusXP source of truth, and the
-- sync services perform one explicit per-user refresh when their writes finish.
DROP TRIGGER IF EXISTS trigger_update_leaderboard_on_progress
  ON public.user_progress;

COMMIT;

-- Post-deploy verification (expect zero rows):
-- SELECT event_object_schema, event_object_table, trigger_name
-- FROM information_schema.triggers
-- WHERE trigger_name IN (
--   'trigger_update_leaderboard_on_achievements',
--   'refresh_leaderboards_after_achievement_sync',
--   'trigger_update_leaderboard_on_progress'
-- );

-- The sync completion paths that replace these triggers are:
--   sync-service/psn-sync.js
--   sync-service/xbox-sync.js
--   sync-service/steam-sync.js
-- Each invokes public.refresh_statusxp_leaderboard_for_user(p_user_id).
