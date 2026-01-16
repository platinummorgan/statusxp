-- Clear all sync timestamps to allow immediate syncing for all users
-- This will allow everyone to sync PSN, Xbox, and Steam immediately

UPDATE profiles
SET 
  last_psn_sync_at = NULL,
  last_xbox_sync_at = NULL,
  last_steam_sync_at = NULL
WHERE 
  last_psn_sync_at IS NOT NULL 
  OR last_xbox_sync_at IS NOT NULL 
  OR last_steam_sync_at IS NOT NULL;

-- Check how many profiles were updated
SELECT COUNT(*) as profiles_reset FROM profiles
WHERE last_psn_sync_at IS NULL 
  AND last_xbox_sync_at IS NULL 
  AND last_steam_sync_at IS NULL;
