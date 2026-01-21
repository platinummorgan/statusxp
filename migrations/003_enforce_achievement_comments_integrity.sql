-- ============================================================================
-- Migration: 003_enforce_achievement_comments_integrity
-- Description: Add FK constraint or create filtered view for orphan handling
-- ============================================================================
-- Two options provided:
-- - OPTION A (RECOMMENDED): Delete orphan row and add FK constraint
-- - OPTION B (SAFER): Keep orphan, create filtered view, defer FK enforcement
--
-- Choose ONE option by uncommenting the appropriate section below.
-- ============================================================================

-- ============================================================================
-- OPTION A: DELETE ORPHAN AND ADD FK CONSTRAINT (RECOMMENDED)
-- ============================================================================
-- Enforces referential integrity immediately by removing the orphan row
-- and adding a proper foreign key constraint.
--
-- UNCOMMENT THIS SECTION TO USE OPTION A:
-- ============================================================================

-- Delete the known orphan row
DELETE FROM public.achievement_comments
WHERE id = '01399bfa-ba17-40b6-92e6-d3f2c003949f'
  AND achievement_id = 281838
  AND platform_id IS NULL;

-- Verify deletion
DO $$
DECLARE
  v_deleted_count bigint;
BEGIN
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % orphan comment(s)', v_deleted_count;
END $$;

-- Make the composite columns NOT NULL
ALTER TABLE public.achievement_comments
  ALTER COLUMN platform_id SET NOT NULL,
  ALTER COLUMN platform_game_id SET NOT NULL,
  ALTER COLUMN platform_achievement_id SET NOT NULL;

-- Add composite foreign key constraint
ALTER TABLE public.achievement_comments
  ADD CONSTRAINT achievement_comments_achievement_fkey
  FOREIGN KEY (platform_id, platform_game_id, platform_achievement_id)
  REFERENCES public.achievements(platform_id, platform_game_id, platform_achievement_id)
  ON DELETE CASCADE;

-- Create composite index to support the FK and queries
CREATE INDEX IF NOT EXISTS idx_achievement_comments_achievement_composite
  ON public.achievement_comments(platform_id, platform_game_id, platform_achievement_id);

-- Drop the old single-column index (no longer needed)
DROP INDEX IF EXISTS public.idx_achievement_comments_achievement_id;
DROP INDEX IF EXISTS public.idx_achievement_comments_achievement_id_backfill;

-- Add comment noting the old column is deprecated
COMMENT ON COLUMN public.achievement_comments.achievement_id IS 
  'DEPRECATED: Use (platform_id, platform_game_id, platform_achievement_id) composite FK instead. Will be removed in future migration.';

-- Final status report
DO $$
BEGIN
  RAISE NOTICE 'Option A complete: Orphan deleted, FK constraint added';
END $$;

-- ============================================================================
-- OPTION B: KEEP ORPHAN, CREATE FILTERED VIEW (SAFER)
-- ============================================================================
-- Keeps the orphan row but creates a view that filters it out.
-- Use this if you need to investigate the orphan or preserve it temporarily.
--
-- UNCOMMENT THIS SECTION TO USE OPTION B:
-- ============================================================================

/*
-- Create a view that only shows comments with valid achievement references
CREATE OR REPLACE VIEW public.achievement_comments_attached AS
SELECT 
  ac.id,
  ac.achievement_id,
  ac.platform_id,
  ac.platform_game_id,
  ac.platform_achievement_id,
  ac.user_id,
  ac.comment_text,
  ac.created_at,
  ac.updated_at,
  ac.is_hidden,
  ac.is_flagged,
  ac.flag_count
FROM public.achievement_comments ac
WHERE ac.platform_id IS NOT NULL
  AND ac.platform_game_id IS NOT NULL
  AND ac.platform_achievement_id IS NOT NULL;

-- Add comment explaining the view
COMMENT ON VIEW public.achievement_comments_attached IS 
  'Filtered view of achievement_comments showing only rows with valid achievement references. Excludes orphaned comments.';

-- Create composite index to support queries (even without FK)
CREATE INDEX IF NOT EXISTS idx_achievement_comments_achievement_composite
  ON public.achievement_comments(platform_id, platform_game_id, platform_achievement_id)
  WHERE platform_id IS NOT NULL 
    AND platform_game_id IS NOT NULL 
    AND platform_achievement_id IS NOT NULL;

-- Report status
DO $$
DECLARE
  v_total_count bigint;
  v_attached_count bigint;
  v_orphan_count bigint;
BEGIN
  SELECT COUNT(*) INTO v_total_count FROM public.achievement_comments;
  SELECT COUNT(*) INTO v_attached_count FROM public.achievement_comments_attached;
  v_orphan_count := v_total_count - v_attached_count;
  
  RAISE NOTICE 'Option B complete: View created with % attached comments (% orphans excluded)', 
    v_attached_count, v_orphan_count;
  RAISE NOTICE 'To enforce FK later, investigate/fix orphans then run:';
  RAISE NOTICE '  ALTER TABLE achievement_comments ADD CONSTRAINT achievement_comments_achievement_fkey';
  RAISE NOTICE '    FOREIGN KEY (platform_id, platform_game_id, platform_achievement_id)';
  RAISE NOTICE '    REFERENCES achievements(platform_id, platform_game_id, platform_achievement_id) ON DELETE CASCADE;';
END $$;
*/

-- ============================================================================
-- MANUAL DECISION REQUIRED
-- ============================================================================
-- OPTION A has been selected and uncommented.
-- This migration will delete the orphan comment and enforce FK integrity.
-- ============================================================================

-- ============================================================================
-- ROLLBACK SCRIPT FOR OPTION A
-- ============================================================================
-- To rollback Option A, run:
--
-- DROP INDEX IF EXISTS public.idx_achievement_comments_achievement_composite;
-- 
-- ALTER TABLE public.achievement_comments
--   DROP CONSTRAINT IF EXISTS achievement_comments_achievement_fkey;
--
-- ALTER TABLE public.achievement_comments
--   ALTER COLUMN platform_id DROP NOT NULL,
--   ALTER COLUMN platform_game_id DROP NOT NULL,
--   ALTER COLUMN platform_achievement_id DROP NOT NULL;
--
-- -- Restore the orphan row (if you saved it)
-- -- INSERT INTO public.achievement_comments (id, achievement_id, user_id, comment_text, created_at, updated_at)
-- -- VALUES ('01399bfa-ba17-40b6-92e6-d3f2c003949f', 281838, ..., ..., ..., ...);
--
-- CREATE INDEX IF NOT EXISTS idx_achievement_comments_achievement_id 
--   ON public.achievement_comments(achievement_id);
-- ============================================================================

-- ============================================================================
-- ROLLBACK SCRIPT FOR OPTION B
-- ============================================================================
-- To rollback Option B, run:
--
-- DROP VIEW IF EXISTS public.achievement_comments_attached;
-- DROP INDEX IF EXISTS public.idx_achievement_comments_achievement_composite;
-- ============================================================================

-- ============================================================================
-- FUTURE MIGRATION: Remove Deprecated achievement_id Column
-- ============================================================================
-- After confirming the composite FK is working and application code is updated,
-- run this to clean up:
--
-- ALTER TABLE public.achievement_comments
--   DROP COLUMN IF EXISTS achievement_id;
-- ============================================================================
