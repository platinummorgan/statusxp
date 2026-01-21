-- ============================================================================
-- Migration: 001_add_achievement_composite_columns_to_comments
-- Description: Add proper composite key columns to achievement_comments table
-- ============================================================================
-- Achievement_comments currently has achievement_id bigint which doesn't
-- properly reference achievements' composite PK. This migration adds the
-- three required columns for proper foreign key support.
-- ============================================================================

-- Add three columns to store the achievement composite key
ALTER TABLE public.achievement_comments
  ADD COLUMN IF NOT EXISTS platform_id bigint,
  ADD COLUMN IF NOT EXISTS platform_game_id text,
  ADD COLUMN IF NOT EXISTS platform_achievement_id text;

-- Add comment documenting the purpose
COMMENT ON COLUMN public.achievement_comments.platform_id IS 'Part of composite FK to achievements (platform_id, platform_game_id, platform_achievement_id)';
COMMENT ON COLUMN public.achievement_comments.platform_game_id IS 'Part of composite FK to achievements (platform_id, platform_game_id, platform_achievement_id)';
COMMENT ON COLUMN public.achievement_comments.platform_achievement_id IS 'Part of composite FK to achievements (platform_id, platform_game_id, platform_achievement_id). Initially backfilled from achievement_id::text';

-- Add index on the old achievement_id for backfill performance (if not exists)
CREATE INDEX IF NOT EXISTS idx_achievement_comments_achievement_id_backfill 
  ON public.achievement_comments(achievement_id);

-- ============================================================================
-- ROLLBACK SCRIPT
-- ============================================================================
-- To rollback this migration, run:
--
-- DROP INDEX IF EXISTS public.idx_achievement_comments_achievement_id_backfill;
-- 
-- ALTER TABLE public.achievement_comments
--   DROP COLUMN IF EXISTS platform_id,
--   DROP COLUMN IF EXISTS platform_game_id,
--   DROP COLUMN IF EXISTS platform_achievement_id;
-- ============================================================================
