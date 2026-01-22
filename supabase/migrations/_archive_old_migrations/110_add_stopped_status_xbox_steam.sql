-- Migration: 110_add_stopped_status_xbox_steam.sql
-- Created: 2025-12-30
-- Description: Add 'stopped' status to Xbox sync and create Steam sync columns
--
-- BUG FIX: When users press "Stop Sync", the sync service was setting status to 'idle'
-- which is not a valid status value. This caused the app to show "syncing" after reopen.
-- This migration adds 'stopped' as a valid status for Xbox and creates Steam columns.

-- ============================================================================
-- XBOX: Add 'stopped' to sync status constraint
-- ============================================================================

-- Drop existing constraint
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_xbox_sync_status_check;

-- Add new constraint with 'stopped' status
ALTER TABLE profiles 
  ADD CONSTRAINT profiles_xbox_sync_status_check 
  CHECK (xbox_sync_status IN ('never_synced', 'pending', 'syncing', 'success', 'error', 'stopped'));

COMMENT ON CONSTRAINT profiles_xbox_sync_status_check ON profiles IS 
  'Valid Xbox sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user)';

-- ============================================================================
-- STEAM: Add sync status columns (includes 'stopped' from the start)
-- ============================================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS steam_api_key text,
  ADD COLUMN IF NOT EXISTS last_steam_sync_at timestamptz,
  ADD COLUMN IF NOT EXISTS steam_sync_status text DEFAULT 'never_synced' 
    CHECK (steam_sync_status IN ('never_synced', 'pending', 'syncing', 'success', 'error', 'stopped')),
  ADD COLUMN IF NOT EXISTS steam_sync_error text,
  ADD COLUMN IF NOT EXISTS steam_sync_progress int DEFAULT 0;

-- Add index for sync status queries
CREATE INDEX IF NOT EXISTS idx_profiles_steam_sync_status ON profiles(steam_sync_status);

-- Add comments
COMMENT ON COLUMN profiles.steam_api_key IS 'User Steam Web API key for accessing achievements';
COMMENT ON COLUMN profiles.last_steam_sync_at IS 'Last successful Steam achievement sync timestamp';
COMMENT ON COLUMN profiles.steam_sync_status IS 'Current status of Steam sync process';
COMMENT ON COLUMN profiles.steam_sync_error IS 'Error message from last failed sync';
COMMENT ON COLUMN profiles.steam_sync_progress IS 'Sync progress percentage (0-100)';
