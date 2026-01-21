-- ============================================================================
-- Migration: 005_optional_cleanup_auth_user_fks
-- Description: Remove old auth.users FK constraints after app switches to profiles
-- ============================================================================
-- ⚠️ DO NOT RUN THIS MIGRATION until:
-- 1. Application code has been updated to use profile_id columns
-- 2. All queries have been verified to work with new columns
-- 3. Production has been stable for at least 1 week
-- 4. You have a backup/rollback plan
--
-- This migration removes the old user_id/helper_user_id FK constraints to
-- auth.users and optionally drops the old columns entirely.
-- ============================================================================

-- ============================================================================
-- PREFLIGHT CHECK: Verify new columns are being used
-- ============================================================================

DO $$
DECLARE
  v_flex_profile_nulls bigint;
  v_requests_profile_nulls bigint;
  v_responses_profile_nulls bigint;
BEGIN
  RAISE NOTICE '=== PREFLIGHT CHECK: NEW PROFILE COLUMNS ===';
  
  SELECT COUNT(*) INTO v_flex_profile_nulls
  FROM flex_room_data WHERE profile_id IS NULL;
  
  SELECT COUNT(*) INTO v_requests_profile_nulls
  FROM trophy_help_requests WHERE profile_id IS NULL;
  
  SELECT COUNT(*) INTO v_responses_profile_nulls
  FROM trophy_help_responses WHERE helper_profile_id IS NULL;
  
  RAISE NOTICE 'flex_room_data.profile_id NULLs: %', v_flex_profile_nulls;
  RAISE NOTICE 'trophy_help_requests.profile_id NULLs: %', v_requests_profile_nulls;
  RAISE NOTICE 'trophy_help_responses.helper_profile_id NULLs: %', v_responses_profile_nulls;
  
  IF v_flex_profile_nulls > 0 OR v_requests_profile_nulls > 0 OR v_responses_profile_nulls > 0 THEN
    RAISE EXCEPTION 'ABORT: New profile_id columns have NULL values - app may not be using them yet!';
  END IF;
  
  RAISE NOTICE '✓ All new profile columns populated - safe to proceed';
END $$;

-- ============================================================================
-- DECISION POINT: Choose one of two cleanup strategies
-- ============================================================================
-- OPTION A: Drop FK constraints but keep columns (safer, allows gradual migration)
-- OPTION B: Drop FK constraints AND columns (complete cleanup)
--
-- Uncomment the option you want to use

-- ============================================================================
-- OPTION A: DROP FK CONSTRAINTS ONLY (RECOMMENDED)
-- ============================================================================
-- Keeps old columns for reference but removes auth.users dependency

BEGIN;

-- Drop FK constraint from flex_room_data
ALTER TABLE public.flex_room_data
  DROP CONSTRAINT IF EXISTS flex_room_data_user_id_fkey;

-- Drop FK constraint from trophy_help_requests
ALTER TABLE public.trophy_help_requests
  DROP CONSTRAINT IF EXISTS trophy_help_requests_user_id_fkey;

-- Drop FK constraint from trophy_help_responses
ALTER TABLE public.trophy_help_responses
  DROP CONSTRAINT IF EXISTS trophy_help_responses_helper_user_id_fkey;

-- Mark old columns as deprecated
COMMENT ON COLUMN public.flex_room_data.user_id IS 
  'DEPRECATED: Use profile_id instead. Column kept for reference only. FK constraint removed.';

COMMENT ON COLUMN public.trophy_help_requests.user_id IS 
  'DEPRECATED: Use profile_id instead. Column kept for reference only. FK constraint removed.';

COMMENT ON COLUMN public.trophy_help_responses.helper_user_id IS 
  'DEPRECATED: Use helper_profile_id instead. Column kept for reference only. FK constraint removed.';

COMMIT;

RAISE NOTICE 'Option A complete: FK constraints dropped, columns preserved';

-- ============================================================================
-- OPTION B: DROP FK CONSTRAINTS AND COLUMNS (COMPLETE CLEANUP)
-- ============================================================================
-- ⚠️ ONLY USE IF YOU ARE 100% CERTAIN THE APP NO LONGER USES THESE COLUMNS

/*
BEGIN;

-- flex_room_data: drop FK and column
ALTER TABLE public.flex_room_data
  DROP CONSTRAINT IF EXISTS flex_room_data_user_id_fkey,
  DROP COLUMN IF EXISTS user_id;

-- trophy_help_requests: drop FK and column
ALTER TABLE public.trophy_help_requests
  DROP CONSTRAINT IF EXISTS trophy_help_requests_user_id_fkey,
  DROP COLUMN IF EXISTS user_id;

-- trophy_help_responses: drop FK and column
ALTER TABLE public.trophy_help_responses
  DROP CONSTRAINT IF EXISTS trophy_help_responses_helper_user_id_fkey,
  DROP COLUMN IF EXISTS helper_user_id;

COMMIT;

RAISE NOTICE 'Option B complete: FK constraints and columns dropped';
*/

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify auth.users FK constraints are gone
SELECT
  tc.table_name,
  tc.constraint_name,
  kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name IN ('flex_room_data', 'trophy_help_requests', 'trophy_help_responses')
  AND tc.constraint_name IN (
    'flex_room_data_user_id_fkey',
    'trophy_help_requests_user_id_fkey',
    'trophy_help_responses_helper_user_id_fkey'
  );
-- Should return 0 rows

-- Verify profile FK constraints still exist
SELECT
  tc.table_name,
  tc.constraint_name,
  kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.constraint_name IN (
    'flex_room_data_profile_id_fkey',
    'trophy_help_requests_profile_id_fkey',
    'trophy_help_responses_helper_profile_id_fkey'
  );
-- Should return 3 rows

-- If using Option A: verify old columns still exist
SELECT 
  table_name,
  column_name,
  data_type,
  col_description(
    (table_schema||'.'||table_name)::regclass::oid,
    ordinal_position
  ) as description
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('flex_room_data', 'trophy_help_requests', 'trophy_help_responses')
  AND column_name IN ('user_id', 'helper_user_id')
ORDER BY table_name, column_name;

-- ============================================================================
-- ROLLBACK SCRIPT FOR OPTION A
-- ============================================================================
/*
BEGIN;

-- Re-add FK constraints to auth.users
ALTER TABLE public.flex_room_data
  ADD CONSTRAINT flex_room_data_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

ALTER TABLE public.trophy_help_requests
  ADD CONSTRAINT trophy_help_requests_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

ALTER TABLE public.trophy_help_responses
  ADD CONSTRAINT trophy_help_responses_helper_user_id_fkey
  FOREIGN KEY (helper_user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- Remove deprecation comments
COMMENT ON COLUMN public.flex_room_data.user_id IS NULL;
COMMENT ON COLUMN public.trophy_help_requests.user_id IS NULL;
COMMENT ON COLUMN public.trophy_help_responses.helper_user_id IS NULL;

COMMIT;
*/

-- ============================================================================
-- ROLLBACK SCRIPT FOR OPTION B
-- ============================================================================
/*
-- Cannot rollback Option B without data loss!
-- You would need to:
-- 1. Re-add columns
-- 2. Backfill from profile_id (assuming profiles.id == auth.users.id)
-- 3. Re-add FK constraints
-- This is complex and error-prone - do not use Option B unless certain!

BEGIN;

-- Re-add columns
ALTER TABLE public.flex_room_data ADD COLUMN user_id uuid;
ALTER TABLE public.trophy_help_requests ADD COLUMN user_id uuid;
ALTER TABLE public.trophy_help_responses ADD COLUMN helper_user_id uuid;

-- Backfill
UPDATE public.flex_room_data SET user_id = profile_id;
UPDATE public.trophy_help_requests SET user_id = profile_id;
UPDATE public.trophy_help_responses SET helper_user_id = helper_profile_id;

-- Set NOT NULL
ALTER TABLE public.flex_room_data ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.trophy_help_requests ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.trophy_help_responses ALTER COLUMN helper_user_id SET NOT NULL;

-- Re-add FK constraints
ALTER TABLE public.flex_room_data
  ADD CONSTRAINT flex_room_data_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.trophy_help_requests
  ADD CONSTRAINT trophy_help_requests_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.trophy_help_responses
  ADD CONSTRAINT trophy_help_responses_helper_user_id_fkey
  FOREIGN KEY (helper_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

COMMIT;
*/

-- ============================================================================
-- FINAL CLEANUP (OPTIONAL): Drop profile_id columns if reverting completely
-- ============================================================================
/*
-- Only run this if you're reverting the entire migration series

BEGIN;

ALTER TABLE public.flex_room_data DROP COLUMN IF EXISTS profile_id;
ALTER TABLE public.trophy_help_requests DROP COLUMN IF EXISTS profile_id;
ALTER TABLE public.trophy_help_responses DROP COLUMN IF EXISTS helper_profile_id;

COMMIT;

-- Drop indexes
DROP INDEX CONCURRENTLY IF EXISTS public.idx_flex_room_data_profile_id;
DROP INDEX CONCURRENTLY IF EXISTS public.idx_trophy_help_requests_profile_status;
DROP INDEX CONCURRENTLY IF EXISTS public.idx_trophy_help_responses_helper_profile;
*/
