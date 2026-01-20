-- Reset DanyGT37's sync status to force fresh sync
-- This will:
-- 1. Clear PSN last sync date
-- 2. Clear Steam last sync date
-- 3. Reset sync progress to 0
-- 4. Clear any sync errors
-- Next time they open the app, it will trigger a full sync

UPDATE profiles
SET 
  psn_last_sync = NULL,
  steam_last_sync = NULL,
  psn_sync_progress = 0,
  steam_sync_progress = 0
WHERE id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Verify the reset
SELECT 
  display_name,
  psn_last_sync,
  steam_last_sync,
  psn_sync_progress,
  steam_sync_progress,
  psn_online_id,
  steam_id
FROM profiles
WHERE id = '68de8222-9da5-4362-ac9b-96b302a7d455';
