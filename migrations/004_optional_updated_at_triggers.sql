-- ============================================================================
-- Migration: 004_optional_updated_at_triggers
-- Description: Add automatic updated_at timestamp maintenance
-- ============================================================================
-- Creates a reusable trigger function and applies it to tables with updated_at
-- columns that lack automatic maintenance.
-- OPTIONAL: Only run if you want automatic timestamp updates.
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Create reusable updated_at trigger function
-- ============================================================================
-- This function can be used by multiple tables

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_updated_at_column() IS 
  'Automatically updates updated_at column to current timestamp on row UPDATE';

-- ============================================================================
-- STEP 2: Add triggers to tables with updated_at columns
-- ============================================================================

-- trophy_help_requests.updated_at trigger
DROP TRIGGER IF EXISTS set_updated_at ON public.trophy_help_requests;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.trophy_help_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- achievement_comments.updated_at trigger
DROP TRIGGER IF EXISTS set_updated_at ON public.achievement_comments;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.achievement_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- STEP 3: Add trigger for flex_room_data.last_updated
-- ============================================================================
-- flex_room_data uses last_updated instead of updated_at

CREATE OR REPLACE FUNCTION public.update_flex_room_last_updated()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_updated = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_last_updated ON public.flex_room_data;

CREATE TRIGGER set_last_updated
  BEFORE UPDATE ON public.flex_room_data
  FOR EACH ROW
  EXECUTE FUNCTION public.update_flex_room_last_updated();

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify trigger functions exist
SELECT 
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('update_updated_at_column', 'update_flex_room_last_updated');

-- Verify triggers are active
SELECT 
  event_object_table as table_name,
  trigger_name,
  event_manipulation as event,
  action_timing as timing
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND trigger_name IN ('set_updated_at', 'set_last_updated')
ORDER BY event_object_table;

-- Test the triggers work
DO $$
DECLARE
  v_test_request_id uuid;
  v_old_timestamp timestamptz;
  v_new_timestamp timestamptz;
BEGIN
  -- Test trophy_help_requests trigger
  SELECT id, updated_at INTO v_test_request_id, v_old_timestamp
  FROM trophy_help_requests
  LIMIT 1;
  
  IF v_test_request_id IS NOT NULL THEN
    -- Wait a moment to ensure timestamp difference
    PERFORM pg_sleep(0.1);
    
    -- Update the row
    UPDATE trophy_help_requests
    SET description = description  -- Dummy update
    WHERE id = v_test_request_id;
    
    -- Check if timestamp changed
    SELECT updated_at INTO v_new_timestamp
    FROM trophy_help_requests
    WHERE id = v_test_request_id;
    
    IF v_new_timestamp > v_old_timestamp THEN
      RAISE NOTICE '✓ trophy_help_requests trigger working: timestamp updated from % to %', v_old_timestamp, v_new_timestamp;
    ELSE
      RAISE WARNING '✗ trophy_help_requests trigger may not be working';
    END IF;
  ELSE
    RAISE NOTICE 'No trophy_help_requests to test - trigger will work when data exists';
  END IF;
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT
-- ============================================================================
/*
BEGIN;

-- Drop triggers
DROP TRIGGER IF EXISTS set_updated_at ON public.trophy_help_requests;
DROP TRIGGER IF EXISTS set_updated_at ON public.achievement_comments;
DROP TRIGGER IF EXISTS set_last_updated ON public.flex_room_data;

-- Drop trigger functions
DROP FUNCTION IF EXISTS public.update_updated_at_column();
DROP FUNCTION IF EXISTS public.update_flex_room_last_updated();

COMMIT;
*/
