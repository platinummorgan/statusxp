-- Clear all sync statuses for all users
-- Use this to reset stuck syncs across all platforms

-- Option 1: Clear for ALL users (set to NULL = no sync in progress)
UPDATE profiles 
SET 
  psn_sync_status = NULL,
  psn_sync_progress = 0,
  psn_sync_error = NULL,
  xbox_sync_status = NULL,
  xbox_sync_progress = 0,
  xbox_sync_error = NULL,
  steam_sync_status = NULL,
  steam_sync_progress = 0,
  steam_sync_error = NULL;

-- Option 2: Clear for a specific user
-- UPDATE profiles 
-- SET 
--   psn_sync_status = NULL,
--   psn_sync_progress = 0,
--   psn_sync_error = NULL,
--   xbox_sync_status = NULL,
--   xbox_sync_progress = 0,
--   xbox_sync_error = NULL,
--   steam_sync_status = NULL,
--   steam_sync_progress = 0,
--   steam_sync_error = NULL
-- WHERE id = 'USER_ID_HERE';

-- Option 3: Clear for a specific user by gamertag
-- UPDATE profiles 
-- SET 
--   psn_sync_status = NULL,
--   psn_sync_progress = 0,
--   psn_sync_error = NULL,
--   xbox_sync_status = NULL,
--   xbox_sync_progress = 0,
--   xbox_sync_error = NULL,
--   steam_sync_status = NULL,
--   steam_sync_progress = 0,
--   steam_sync_error = NULL
-- WHERE xbox_gamertag = 'GAMERTAG_HERE' 
--    OR psn_online_id = 'PSN_ID_HERE';

-- Verify the update
SELECT 
  id,
  psn_online_id,
  xbox_gamertag,
  psn_sync_status,
  xbox_sync_status,
  steam_sync_status
FROM profiles 
ORDER BY last_psn_sync_at DESC NULLS LAST
LIMIT 10;
