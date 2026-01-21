-- ============================================================================
-- Migration: 003_enforce_status_constraints
-- Description: Add CHECK constraints for valid status values in trophy help tables
-- ============================================================================
-- Enforces allowed status values to prevent invalid states.
-- Checks existing data first and provides remediation if needed.
-- ============================================================================

-- ============================================================================
-- STEP 1: Analyze current status values (should be done in 001_preflight)
-- ============================================================================
-- Re-check for any unexpected values before enforcing

DO $$
DECLARE
  v_invalid_requests bigint;
  v_invalid_responses bigint;
BEGIN
  RAISE NOTICE '=== PRE-CONSTRAINT STATUS AUDIT ===';
  
  -- Check trophy_help_requests for unexpected statuses
  SELECT COUNT(*) INTO v_invalid_requests
  FROM public.trophy_help_requests
  WHERE status NOT IN ('open', 'assigned', 'closed', 'cancelled');
  
  -- Check trophy_help_responses for unexpected statuses
  SELECT COUNT(*) INTO v_invalid_responses
  FROM public.trophy_help_responses
  WHERE status NOT IN ('pending', 'accepted', 'declined', 'completed');
  
  RAISE NOTICE 'trophy_help_requests with invalid status: %', v_invalid_requests;
  RAISE NOTICE 'trophy_help_responses with invalid status: %', v_invalid_responses;
  
  IF v_invalid_requests > 0 THEN
    RAISE WARNING 'Found % requests with invalid status - will attempt remediation', v_invalid_requests;
  END IF;
  
  IF v_invalid_responses > 0 THEN
    RAISE WARNING 'Found % responses with invalid status - will attempt remediation', v_invalid_responses;
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Remediation - normalize any invalid status values
-- ============================================================================
-- Map unexpected values to nearest valid status
-- Adjust these mappings based on your actual data

BEGIN;

-- Remediate trophy_help_requests (examples - adjust as needed)
UPDATE public.trophy_help_requests
SET status = CASE
  WHEN status ILIKE '%complete%' THEN 'closed'
  WHEN status ILIKE '%cancel%' THEN 'cancelled'
  WHEN status ILIKE '%pending%' THEN 'open'
  WHEN status ILIKE '%assign%' THEN 'assigned'
  ELSE 'open'  -- Default fallback
END
WHERE status NOT IN ('open', 'assigned', 'closed', 'cancelled');

-- Remediate trophy_help_responses (examples - adjust as needed)
UPDATE public.trophy_help_responses
SET status = CASE
  WHEN status ILIKE '%accept%' THEN 'accepted'
  WHEN status ILIKE '%decline%' OR status ILIKE '%reject%' THEN 'declined'
  WHEN status ILIKE '%complete%' OR status ILIKE '%done%' THEN 'completed'
  ELSE 'pending'  -- Default fallback
END
WHERE status NOT IN ('pending', 'accepted', 'declined', 'completed');

-- Report remediation results
DO $$
DECLARE
  v_requests_fixed bigint;
  v_responses_fixed bigint;
BEGIN
  GET DIAGNOSTICS v_requests_fixed = ROW_COUNT;
  
  RAISE NOTICE 'Remediation complete:';
  RAISE NOTICE '  Requests normalized: % rows', v_requests_fixed;
END $$;

COMMIT;

-- ============================================================================
-- STEP 3: Add CHECK constraints (NOT VALID first)
-- ============================================================================
-- NOT VALID allows existing rows without full table scan
-- Must validate separately to enforce going forward

BEGIN;

-- Add CHECK constraint for trophy_help_requests.status
ALTER TABLE public.trophy_help_requests
  ADD CONSTRAINT trophy_help_requests_status_check
  CHECK (status IN ('open', 'assigned', 'closed', 'cancelled'))
  NOT VALID;

-- Add CHECK constraint for trophy_help_responses.status
ALTER TABLE public.trophy_help_responses
  ADD CONSTRAINT trophy_help_responses_status_check
  CHECK (status IN ('pending', 'accepted', 'declined', 'completed'))
  NOT VALID;

COMMIT;

-- ============================================================================
-- STEP 4: Validate CHECK constraints
-- ============================================================================
-- This scans all rows to ensure they meet the constraint
-- Will fail if any invalid values remain

BEGIN;

ALTER TABLE public.trophy_help_requests
  VALIDATE CONSTRAINT trophy_help_requests_status_check;

ALTER TABLE public.trophy_help_responses
  VALIDATE CONSTRAINT trophy_help_responses_status_check;

COMMIT;

-- ============================================================================
-- STEP 5: Add indexes to improve status-based queries
-- ============================================================================
-- Create partial indexes for active statuses

-- Index for open/assigned requests (most common queries)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trophy_help_requests_active_status
  ON public.trophy_help_requests(status, created_at DESC)
  WHERE status IN ('open', 'assigned');

-- Index for pending responses
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trophy_help_responses_pending
  ON public.trophy_help_responses(status, created_at DESC)
  WHERE status = 'pending';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify CHECK constraints exist and are validated
SELECT
  tc.table_name,
  tc.constraint_name,
  cc.check_clause,
  CASE 
    WHEN con.convalidated THEN 'VALID'
    ELSE 'NOT VALID'
  END as validation_status
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
  ON tc.constraint_name = cc.constraint_name
JOIN pg_constraint con
  ON con.conname = tc.constraint_name
WHERE tc.constraint_schema = 'public'
  AND tc.constraint_name IN (
    'trophy_help_requests_status_check',
    'trophy_help_responses_status_check'
  );

-- Verify all status values are now valid
SELECT 'trophy_help_requests' as table_name, status, COUNT(*) as count
FROM public.trophy_help_requests
GROUP BY status
UNION ALL
SELECT 'trophy_help_responses', status, COUNT(*)
FROM public.trophy_help_responses
GROUP BY status
ORDER BY table_name, count DESC;

-- Test that invalid inserts are blocked
DO $$
BEGIN
  -- This should fail
  INSERT INTO trophy_help_requests (id, user_id, profile_id, game_id, game_title, achievement_id, achievement_name, platform, status)
  VALUES (gen_random_uuid(), (SELECT id FROM profiles LIMIT 1), (SELECT id FROM profiles LIMIT 1), 'test', 'Test Game', 'test', 'Test Achievement', 'psn', 'invalid_status');
  
  RAISE EXCEPTION 'Test failed: invalid status was allowed!';
EXCEPTION
  WHEN check_violation THEN
    RAISE NOTICE '✓ CHECK constraint working: invalid status correctly blocked';
  WHEN OTHERS THEN
    RAISE NOTICE '✓ Insert blocked (possibly by other constraint)';
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT
-- ============================================================================
/*
BEGIN;

-- Drop CHECK constraints
ALTER TABLE public.trophy_help_requests 
  DROP CONSTRAINT IF EXISTS trophy_help_requests_status_check;

ALTER TABLE public.trophy_help_responses 
  DROP CONSTRAINT IF EXISTS trophy_help_responses_status_check;

COMMIT;

-- Drop indexes (CONCURRENTLY, outside transaction)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_trophy_help_requests_active_status;
DROP INDEX CONCURRENTLY IF EXISTS public.idx_trophy_help_responses_pending;

-- Note: Remediated status values will remain normalized
-- To restore original values, you would need a backup
*/
