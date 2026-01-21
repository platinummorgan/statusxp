-- ============================================================================
-- Migration: 002_backfill_achievement_composite_columns
-- Description: Populate the new composite key columns with data
-- ============================================================================
-- Backfills achievement_comments with proper achievement references:
-- 1. platform_achievement_id from existing achievement_id::text
-- 2. platform_id and platform_game_id from JOIN with achievements table
-- 
-- Known data state:
-- - 4786/4787 rows match achievements
-- - 1 orphan row: id='01399bfa-ba17-40b6-92e6-d3f2c003949f', achievement_id=281838
-- ============================================================================

-- Step 1: Backfill platform_achievement_id from achievement_id
-- This converts the bigint to text to match achievements.platform_achievement_id
UPDATE public.achievement_comments
SET platform_achievement_id = achievement_id::text
WHERE platform_achievement_id IS NULL;

-- Verify backfill
DO $$
DECLARE
  v_backfilled_count bigint;
BEGIN
  SELECT COUNT(*) INTO v_backfilled_count
  FROM public.achievement_comments
  WHERE platform_achievement_id IS NOT NULL;
  
  RAISE NOTICE 'Backfilled platform_achievement_id for % rows', v_backfilled_count;
END $$;

-- Step 2: Backfill platform_id and platform_game_id from achievements table
-- This JOIN will only populate rows that have matching achievements
UPDATE public.achievement_comments ac
SET 
  platform_id = a.platform_id,
  platform_game_id = a.platform_game_id
FROM public.achievements a
WHERE a.platform_achievement_id = ac.platform_achievement_id
  AND ac.platform_id IS NULL;  -- Only update rows not yet populated

-- Verify backfill and report orphans
DO $$
DECLARE
  v_linked_count bigint;
  v_orphan_count bigint;
  v_orphan_ids text;
BEGIN
  -- Count successfully linked comments
  SELECT COUNT(*) INTO v_linked_count
  FROM public.achievement_comments
  WHERE platform_id IS NOT NULL 
    AND platform_game_id IS NOT NULL 
    AND platform_achievement_id IS NOT NULL;
  
  -- Count orphaned comments (no matching achievement)
  SELECT COUNT(*) INTO v_orphan_count
  FROM public.achievement_comments
  WHERE platform_id IS NULL 
    OR platform_game_id IS NULL;
  
  -- Get orphan IDs for logging
  SELECT string_agg(id::text || ' (achievement_id=' || achievement_id || ')', ', ')
  INTO v_orphan_ids
  FROM public.achievement_comments
  WHERE platform_id IS NULL 
    OR platform_game_id IS NULL;
  
  RAISE NOTICE 'Successfully linked % comments to achievements', v_linked_count;
  
  IF v_orphan_count > 0 THEN
    RAISE WARNING 'Found % orphaned comment(s) with no matching achievement: %', v_orphan_count, v_orphan_ids;
  END IF;
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT
-- ============================================================================
-- To rollback this migration, run:
--
-- UPDATE public.achievement_comments
-- SET 
--   platform_id = NULL,
--   platform_game_id = NULL,
--   platform_achievement_id = NULL;
-- ============================================================================
