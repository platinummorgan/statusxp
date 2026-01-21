-- ============================================================================
-- Migration: 001_preflight_and_reports
-- Description: Preflight checks before standardizing user references and constraints
-- ============================================================================
-- This migration performs read-only checks to ensure safe migration execution.
-- Run this first and review output before proceeding with other migrations.
-- ============================================================================

-- ============================================================================
-- CHECK 1: Verify profiles <-> auth.users alignment
-- ============================================================================
-- Every profiles.id should have a matching auth.users.id (they share the same UUID)
-- If any mismatches exist, DO NOT proceed with user reference standardization.

DO $$
DECLARE
  v_orphaned_profiles bigint;
  v_orphaned_auth_users bigint;
BEGIN
  -- Check for profiles without corresponding auth.users
  SELECT COUNT(*) INTO v_orphaned_profiles
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE u.id IS NULL;
  
  -- Check for auth.users without corresponding profiles
  SELECT COUNT(*) INTO v_orphaned_auth_users
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE p.id IS NULL;
  
  RAISE NOTICE '=== PROFILES <-> AUTH.USERS ALIGNMENT CHECK ===';
  RAISE NOTICE 'Profiles without auth.users: %', v_orphaned_profiles;
  RAISE NOTICE 'Auth.users without profiles: %', v_orphaned_auth_users;
  
  IF v_orphaned_profiles > 0 THEN
    RAISE WARNING 'Found % profiles without matching auth.users - investigate before proceeding!', v_orphaned_profiles;
  END IF;
  
  IF v_orphaned_auth_users > 0 THEN
    RAISE NOTICE '% auth.users without profiles - this is normal for non-app users', v_orphaned_auth_users;
  END IF;
  
  IF v_orphaned_profiles = 0 AND v_orphaned_auth_users = 0 THEN
    RAISE NOTICE '✓ Perfect alignment - safe to proceed with user reference standardization';
  ELSIF v_orphaned_profiles = 0 THEN
    RAISE NOTICE '✓ All profiles have auth.users - safe to proceed';
  END IF;
END $$;

-- ============================================================================
-- CHECK 2: Current user reference patterns
-- ============================================================================
-- Report which tables reference auth.users vs profiles

DO $$
DECLARE
  v_count bigint;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== CURRENT USER REFERENCE PATTERNS ===';
  
  -- flex_room_data
  SELECT COUNT(*) INTO v_count FROM public.flex_room_data;
  RAISE NOTICE 'flex_room_data: % rows, user_id -> auth.users (target: profiles)', v_count;
  
  -- trophy_help_requests
  SELECT COUNT(*) INTO v_count FROM public.trophy_help_requests;
  RAISE NOTICE 'trophy_help_requests: % rows, user_id -> auth.users (target: profiles)', v_count;
  
  -- trophy_help_responses
  SELECT COUNT(*) INTO v_count FROM public.trophy_help_responses;
  RAISE NOTICE 'trophy_help_responses: % rows, helper_user_id -> auth.users (target: profiles)', v_count;
END $$;

-- ============================================================================
-- CHECK 3: Existing status values in trophy help tables
-- ============================================================================
-- Identify all status values before enforcing constraints

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TROPHY_HELP_REQUESTS STATUS VALUES ===';
END $$;

SELECT 
  status,
  COUNT(*) as count,
  MIN(created_at) as first_seen,
  MAX(created_at) as last_seen
FROM public.trophy_help_requests
GROUP BY status
ORDER BY count DESC;

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TROPHY_HELP_RESPONSES STATUS VALUES ===';
END $$;

SELECT 
  status,
  COUNT(*) as count,
  MIN(created_at) as first_seen,
  MAX(created_at) as last_seen
FROM public.trophy_help_responses
GROUP BY status
ORDER BY count DESC;

-- ============================================================================
-- CHECK 4: Detect tables with updated_at but no auto-update trigger
-- ============================================================================
-- Find tables that have updated_at columns but might lack automatic triggers

DO $$
DECLARE
  v_has_trigger boolean;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== UPDATED_AT COLUMN AUDIT ===';
  
  -- Check flex_room_data
  SELECT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE event_object_table = 'flex_room_data'
      AND trigger_name LIKE '%updated_at%'
  ) INTO v_has_trigger;
  RAISE NOTICE 'flex_room_data.last_updated: trigger exists = %', v_has_trigger;
  
  -- Check trophy_help_requests
  SELECT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE event_object_table = 'trophy_help_requests'
      AND trigger_name LIKE '%updated_at%'
  ) INTO v_has_trigger;
  RAISE NOTICE 'trophy_help_requests.updated_at: trigger exists = %', v_has_trigger;
  
  -- Check achievement_comments
  SELECT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE event_object_table = 'achievement_comments'
      AND trigger_name LIKE '%updated_at%'
  ) INTO v_has_trigger;
  RAISE NOTICE 'achievement_comments.updated_at: trigger exists = %', v_has_trigger;
END $$;

-- ============================================================================
-- CHECK 5: Existing indexes audit
-- ============================================================================
-- Report current indexes to avoid duplicates

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== EXISTING INDEXES ON TARGET TABLES ===';
END $$;

SELECT 
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('flex_room_data', 'trophy_help_requests', 'trophy_help_responses')
ORDER BY tablename, indexname;

-- ============================================================================
-- CHECK 6: Foreign key constraints to auth.users
-- ============================================================================
-- List all FKs pointing to auth.users that we'll want to supplement with profiles

SELECT
  tc.table_name,
  kcu.column_name,
  tc.constraint_name,
  'auth.users' as referenced_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage ccu
    WHERE ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = 'auth'
      AND ccu.table_name = 'users'
  )
ORDER BY tc.table_name, kcu.column_name;

-- ============================================================================
-- SUMMARY AND GO/NO-GO DECISION
-- ============================================================================

DO $$
DECLARE
  v_orphaned_profiles bigint;
  v_invalid_requests bigint;
  v_invalid_responses bigint;
  v_can_proceed boolean := true;
BEGIN
  -- Re-check critical conditions
  SELECT COUNT(*) INTO v_orphaned_profiles
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE u.id IS NULL;
  
  RAISE NOTICE '';
  RAISE NOTICE '=== MIGRATION READINESS SUMMARY ===';
  
  IF v_orphaned_profiles > 0 THEN
    RAISE WARNING '❌ BLOCKER: % orphaned profiles detected - must resolve before proceeding', v_orphaned_profiles;
    v_can_proceed := false;
  ELSE
    RAISE NOTICE '✓ Profiles/auth.users alignment: PASS';
  END IF;
  
  RAISE NOTICE '✓ Status values reported - review before migration 003';
  RAISE NOTICE '✓ Index audit complete - will avoid duplicates';
  
  IF v_can_proceed THEN
    RAISE NOTICE '';
    RAISE NOTICE '✅ GREEN LIGHT: Safe to proceed with migrations 002-005';
  ELSE
    RAISE NOTICE '';
    RAISE NOTICE '🛑 RED LIGHT: Resolve blockers before proceeding';
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION QUERIES (run after this migration)
-- ============================================================================
-- This migration is read-only, so verification = successful completion

-- To re-run specific checks:
-- SELECT COUNT(*) FROM profiles p LEFT JOIN auth.users u ON u.id = p.id WHERE u.id IS NULL;
-- SELECT status, COUNT(*) FROM trophy_help_requests GROUP BY status;
-- SELECT status, COUNT(*) FROM trophy_help_responses GROUP BY status;

-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- This migration is read-only - no rollback needed
