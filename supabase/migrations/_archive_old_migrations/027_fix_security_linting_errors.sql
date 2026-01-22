-- Migration: Fix Security Linting Errors
-- Purpose: Address Supabase database linter security issues
-- Created: 2025-12-18

-- ============================================================================
-- 1. FIX AUTH.USERS EXPOSURE IN VIEWS
-- ============================================================================

-- Drop and recreate user_sync_status view without SECURITY DEFINER
-- and without directly exposing auth.users data
DROP VIEW IF EXISTS user_sync_status;

CREATE VIEW user_sync_status AS
SELECT 
  ush.user_id,
  ush.platform,
  COUNT(*) FILTER (WHERE ush.synced_at::DATE = CURRENT_DATE) as syncs_today,
  MAX(ush.synced_at) as last_sync_at,
  COALESCE(ups.is_premium, FALSE) as is_premium
FROM user_sync_history ush
LEFT JOIN user_premium_status ups ON ups.user_id = ush.user_id
WHERE ush.success = TRUE
GROUP BY ush.user_id, ush.platform, ups.is_premium;

-- Add RLS to the view
ALTER VIEW user_sync_status SET (security_invoker = true);

-- Grant permissions
GRANT SELECT ON user_sync_status TO authenticated;

-- Create RLS policy for the view (users can only see their own data)
-- Note: Views inherit RLS from their underlying tables

-- ============================================================================
-- 2. CREATE user_ai_status VIEW (if it exists as SECURITY DEFINER)
-- ============================================================================

-- Create a secure view for AI credit status
DROP VIEW IF EXISTS user_ai_status CASCADE;

CREATE VIEW user_ai_status AS
SELECT 
  uac.user_id,
  COALESCE(uac.pack_credits, 0) as pack_credits,
  COALESCE(ups.is_premium, FALSE) as is_premium,
  COALESCE(ups.monthly_ai_credits, 0) as monthly_ai_credits,
  (
    SELECT COUNT(*)
    FROM user_ai_daily_usage uadu
    WHERE uadu.user_id = uac.user_id
      AND uadu.created_at::DATE = CURRENT_DATE
  ) as daily_free_used
FROM user_ai_credits uac
LEFT JOIN user_premium_status ups ON ups.user_id = uac.user_id;

-- Add RLS to the view
ALTER VIEW user_ai_status SET (security_invoker = true);

-- Grant permissions
GRANT SELECT ON user_ai_status TO authenticated;

-- ============================================================================
-- 3. ENABLE RLS ON TABLES WITH POLICIES BUT RLS DISABLED
-- ============================================================================

-- Enable RLS on platforms table
ALTER TABLE platforms ENABLE ROW LEVEL SECURITY;

-- The existing "Public read access" policy should already exist
-- If not, create it:
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'platforms' 
    AND policyname = 'Public read access'
  ) THEN
    CREATE POLICY "Public read access"
      ON platforms FOR SELECT
      TO authenticated, anon
      USING (true);
  END IF;
END $$;

-- Enable RLS on profile_themes table
ALTER TABLE profile_themes ENABLE ROW LEVEL SECURITY;

-- The existing "Public read access" policy should already exist
-- If not, create it:
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profile_themes' 
    AND policyname = 'Public read access'
  ) THEN
    CREATE POLICY "Public read access"
      ON profile_themes FOR SELECT
      TO authenticated, anon
      USING (true);
  END IF;
END $$;

-- ============================================================================
-- 4. ENABLE RLS ON ALL PUBLIC TABLES WITHOUT RLS
-- ============================================================================

-- user_sync_history already has RLS enabled in add_premium_and_sync_limits.sql
-- Double-check it's enabled:
ALTER TABLE user_sync_history ENABLE ROW LEVEL SECURITY;

-- user_ai_credits already has RLS enabled in add_ai_credit_system.sql
-- Double-check it's enabled:
ALTER TABLE user_ai_credits ENABLE ROW LEVEL SECURITY;

-- user_ai_daily_usage already has RLS enabled in add_ai_credit_system.sql
-- Double-check it's enabled:
ALTER TABLE user_ai_daily_usage ENABLE ROW LEVEL SECURITY;

-- user_ai_pack_purchases already has RLS enabled in add_ai_credit_system.sql
-- Double-check it's enabled:
ALTER TABLE user_ai_pack_purchases ENABLE ROW LEVEL SECURITY;

-- user_premium_status already has RLS enabled in add_premium_and_sync_limits.sql
-- Double-check it's enabled:
ALTER TABLE user_premium_status ENABLE ROW LEVEL SECURITY;

-- Enable RLS on psn_sync_log
ALTER TABLE psn_sync_log ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for psn_sync_log
DROP POLICY IF EXISTS "Users can view their own PSN sync logs" ON psn_sync_log;
CREATE POLICY "Users can view their own PSN sync logs"
  ON psn_sync_log FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own PSN sync logs" ON psn_sync_log;
CREATE POLICY "Users can insert their own PSN sync logs"
  ON psn_sync_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own PSN sync logs" ON psn_sync_log;
CREATE POLICY "Users can update their own PSN sync logs"
  ON psn_sync_log FOR UPDATE
  USING (auth.uid() = user_id);

-- Enable RLS on psn_trophy_groups
ALTER TABLE psn_trophy_groups ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for psn_trophy_groups (public read since it's reference data)
DROP POLICY IF EXISTS "Public can view PSN trophy groups" ON psn_trophy_groups;
CREATE POLICY "Public can view PSN trophy groups"
  ON psn_trophy_groups FOR SELECT
  TO authenticated, anon
  USING (true);

-- Enable RLS on psn_user_trophy_profile
ALTER TABLE psn_user_trophy_profile ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for psn_user_trophy_profile
DROP POLICY IF EXISTS "Users can view their own PSN trophy profile" ON psn_user_trophy_profile;
CREATE POLICY "Users can view their own PSN trophy profile"
  ON psn_user_trophy_profile FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own PSN trophy profile" ON psn_user_trophy_profile;
CREATE POLICY "Users can insert their own PSN trophy profile"
  ON psn_user_trophy_profile FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own PSN trophy profile" ON psn_user_trophy_profile;
CREATE POLICY "Users can update their own PSN trophy profile"
  ON psn_user_trophy_profile FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 5. COMMENTS AND DOCUMENTATION
-- ============================================================================

COMMENT ON VIEW user_sync_status IS 'Secure view of user sync status without exposing auth.users data';
COMMENT ON VIEW user_ai_status IS 'Secure view of user AI credit status without exposing auth.users data';

-- ============================================================================
-- 6. VERIFY RLS IS ENABLED
-- ============================================================================

-- This query can be run to verify RLS is enabled on all tables:
-- SELECT schemaname, tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE schemaname = 'public' 
-- AND rowsecurity = false;
