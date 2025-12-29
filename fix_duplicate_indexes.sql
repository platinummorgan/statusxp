-- Fix duplicate indexes (Performance Warning)
-- Drop redundant indexes that are identical to existing ones

-- 1. display_case_items: This is a constraint, not just an index - drop the constraint
ALTER TABLE display_case_items DROP CONSTRAINT IF EXISTS display_case_items_user_id_shelf_position_key;

-- 2. profiles: Keep idx_profiles_xbox, drop the duplicate
DROP INDEX IF EXISTS idx_profiles_xbox_gamertag;

-- 3. user_sync_history: Keep idx_sync_history_user_platform_date (more specific), drop the other
DROP INDEX IF EXISTS idx_user_sync_history_user_platform;

-- Verify remaining indexes
COMMENT ON INDEX display_case_items_user_id_shelf_number_position_in_shelf_key IS 'Unique constraint on user display case positions';
COMMENT ON INDEX idx_profiles_xbox IS 'Index for Xbox gamertag lookups';
COMMENT ON INDEX idx_sync_history_user_platform_date IS 'Index for sync history queries by user, platform, and date';
