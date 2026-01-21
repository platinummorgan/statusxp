-- ============================================================================
-- Migration: 002_add_profile_id_columns_and_backfill
-- Description: Standardize user references to use profiles(id) instead of auth.users(id)
-- ============================================================================
-- Adds new profile_id columns to app-domain tables, backfills from existing
-- user_id columns, and creates FK constraints to profiles(id).
-- Does NOT drop old auth.users FKs - that's optional in migration 005.
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Add new profile_id columns (nullable initially)
-- ============================================================================

-- flex_room_data: add profile_id
ALTER TABLE public.flex_room_data
  ADD COLUMN IF NOT EXISTS profile_id uuid;

COMMENT ON COLUMN public.flex_room_data.profile_id IS 
  'References profiles(id). Replaces user_id (auth.users) for app-domain consistency.';

-- trophy_help_requests: add profile_id  
ALTER TABLE public.trophy_help_requests
  ADD COLUMN IF NOT EXISTS profile_id uuid;

COMMENT ON COLUMN public.trophy_help_requests.profile_id IS 
  'References profiles(id). Replaces user_id (auth.users) for app-domain consistency.';

-- trophy_help_responses: add helper_profile_id
ALTER TABLE public.trophy_help_responses
  ADD COLUMN IF NOT EXISTS helper_profile_id uuid;

COMMENT ON COLUMN public.trophy_help_responses.helper_profile_id IS 
  'References profiles(id). Replaces helper_user_id (auth.users) for app-domain consistency.';

-- ============================================================================
-- STEP 2: Backfill profile_id from existing auth.users references
-- ============================================================================
-- Since profiles.id == auth.users.id (same UUID), we can copy directly

-- Backfill flex_room_data.profile_id from user_id
UPDATE public.flex_room_data
SET profile_id = user_id
WHERE profile_id IS NULL;

-- Backfill trophy_help_requests.profile_id from user_id
UPDATE public.trophy_help_requests
SET profile_id = user_id
WHERE profile_id IS NULL;

-- Backfill trophy_help_responses.helper_profile_id from helper_user_id
UPDATE public.trophy_help_responses
SET helper_profile_id = helper_user_id
WHERE helper_profile_id IS NULL;

-- Verify backfill results
DO $$
DECLARE
  v_flex_nulls bigint;
  v_requests_nulls bigint;
  v_responses_nulls bigint;
BEGIN
  SELECT COUNT(*) INTO v_flex_nulls FROM flex_room_data WHERE profile_id IS NULL;
  SELECT COUNT(*) INTO v_requests_nulls FROM trophy_help_requests WHERE profile_id IS NULL;
  SELECT COUNT(*) INTO v_responses_nulls FROM trophy_help_responses WHERE helper_profile_id IS NULL;
  
  RAISE NOTICE 'Backfill verification:';
  RAISE NOTICE '  flex_room_data nulls: %', v_flex_nulls;
  RAISE NOTICE '  trophy_help_requests nulls: %', v_requests_nulls;
  RAISE NOTICE '  trophy_help_responses nulls: %', v_responses_nulls;
  
  IF v_flex_nulls > 0 OR v_requests_nulls > 0 OR v_responses_nulls > 0 THEN
    RAISE WARNING 'Some profile_id columns still NULL - may indicate auth.users without profiles';
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- STEP 3: Create indexes CONCURRENTLY (outside transaction)
-- ============================================================================
-- Cannot use CONCURRENTLY inside a transaction block

-- flex_room_data: unique index on profile_id (one row per user)
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_flex_room_data_profile_id 
  ON public.flex_room_data(profile_id);

-- trophy_help_requests: composite index for common queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trophy_help_requests_profile_status 
  ON public.trophy_help_requests(profile_id, status, created_at DESC);

-- trophy_help_responses: index on helper_profile_id
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trophy_help_responses_helper_profile 
  ON public.trophy_help_responses(helper_profile_id, created_at DESC);

-- ============================================================================
-- STEP 4: Add foreign key constraints (NOT VALID first, then VALIDATE)
-- ============================================================================

BEGIN;

-- flex_room_data FK (NOT VALID allows existing data, doesn't lock table)
ALTER TABLE public.flex_room_data
  ADD CONSTRAINT flex_room_data_profile_id_fkey
  FOREIGN KEY (profile_id)
  REFERENCES public.profiles(id)
  ON DELETE CASCADE
  NOT VALID;

-- trophy_help_requests FK
ALTER TABLE public.trophy_help_requests
  ADD CONSTRAINT trophy_help_requests_profile_id_fkey
  FOREIGN KEY (profile_id)
  REFERENCES public.profiles(id)
  ON DELETE CASCADE
  NOT VALID;

-- trophy_help_responses FK
ALTER TABLE public.trophy_help_responses
  ADD CONSTRAINT trophy_help_responses_helper_profile_id_fkey
  FOREIGN KEY (helper_profile_id)
  REFERENCES public.profiles(id)
  ON DELETE CASCADE
  NOT VALID;

COMMIT;

-- ============================================================================
-- STEP 5: Validate foreign key constraints
-- ============================================================================
-- This checks all rows but doesn't prevent writes during validation

BEGIN;

ALTER TABLE public.flex_room_data
  VALIDATE CONSTRAINT flex_room_data_profile_id_fkey;

ALTER TABLE public.trophy_help_requests
  VALIDATE CONSTRAINT trophy_help_requests_profile_id_fkey;

ALTER TABLE public.trophy_help_responses
  VALIDATE CONSTRAINT trophy_help_responses_helper_profile_id_fkey;

COMMIT;

-- ============================================================================
-- STEP 6: Make profile_id columns NOT NULL
-- ============================================================================
-- Only after backfill is complete and validated

BEGIN;

ALTER TABLE public.flex_room_data
  ALTER COLUMN profile_id SET NOT NULL;

ALTER TABLE public.trophy_help_requests
  ALTER COLUMN profile_id SET NOT NULL;

ALTER TABLE public.trophy_help_responses
  ALTER COLUMN helper_profile_id SET NOT NULL;

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify all profile_id columns are populated
SELECT 
  'flex_room_data' as table_name,
  COUNT(*) as total_rows,
  COUNT(profile_id) as profile_id_count,
  COUNT(*) - COUNT(profile_id) as nulls
FROM public.flex_room_data
UNION ALL
SELECT 
  'trophy_help_requests',
  COUNT(*),
  COUNT(profile_id),
  COUNT(*) - COUNT(profile_id)
FROM public.trophy_help_requests
UNION ALL
SELECT 
  'trophy_help_responses',
  COUNT(*),
  COUNT(helper_profile_id),
  COUNT(*) - COUNT(helper_profile_id)
FROM public.trophy_help_responses;

-- Verify FK constraints exist
SELECT
  tc.table_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.constraint_name IN (
    'flex_room_data_profile_id_fkey',
    'trophy_help_requests_profile_id_fkey',
    'trophy_help_responses_helper_profile_id_fkey'
  );

-- Verify indexes exist
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'idx_flex_room_data_profile_id',
    'idx_trophy_help_requests_profile_status',
    'idx_trophy_help_responses_helper_profile'
  );

-- ============================================================================
-- ROLLBACK SCRIPT
-- ============================================================================
/*
BEGIN;

-- Drop NOT NULL constraints
ALTER TABLE public.flex_room_data ALTER COLUMN profile_id DROP NOT NULL;
ALTER TABLE public.trophy_help_requests ALTER COLUMN profile_id DROP NOT NULL;
ALTER TABLE public.trophy_help_responses ALTER COLUMN helper_profile_id DROP NOT NULL;

-- Drop FK constraints
ALTER TABLE public.flex_room_data DROP CONSTRAINT IF EXISTS flex_room_data_profile_id_fkey;
ALTER TABLE public.trophy_help_requests DROP CONSTRAINT IF EXISTS trophy_help_requests_profile_id_fkey;
ALTER TABLE public.trophy_help_responses DROP CONSTRAINT IF EXISTS trophy_help_responses_helper_profile_id_fkey;

COMMIT;

-- Drop indexes (CONCURRENTLY, outside transaction)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_flex_room_data_profile_id;
DROP INDEX CONCURRENTLY IF EXISTS public.idx_trophy_help_requests_profile_status;
DROP INDEX CONCURRENTLY IF EXISTS public.idx_trophy_help_responses_helper_profile;

-- Drop columns
BEGIN;
ALTER TABLE public.flex_room_data DROP COLUMN IF EXISTS profile_id;
ALTER TABLE public.trophy_help_requests DROP COLUMN IF EXISTS profile_id;
ALTER TABLE public.trophy_help_responses DROP COLUMN IF EXISTS helper_profile_id;
COMMIT;
*/
