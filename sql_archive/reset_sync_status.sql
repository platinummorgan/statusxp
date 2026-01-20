-- Reset sync status for ALL users

UPDATE profiles 
SET 
  xbox_sync_status = NULL,
  xbox_sync_progress = 0,
  psn_sync_status = NULL,
  psn_sync_progress = 0,
  steam_sync_status = NULL,
  steam_sync_progress = 0
WHERE id IS NOT NULL;

-- Clear any stuck sync logs - just delete them
DELETE FROM xbox_sync_logs WHERE status = 'syncing';
DELETE FROM psn_sync_logs WHERE status = 'syncing';
DELETE FROM steam_sync_logs WHERE status = 'syncing';
