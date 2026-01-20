-- Force stop all running syncs
UPDATE profiles 
SET 
  psn_sync_status = 'stopped',
  psn_sync_progress = 0,
  xbox_sync_status = 'stopped', 
  xbox_sync_progress = 0,
  steam_sync_status = 'stopped',
  steam_sync_progress = 0
WHERE 
  psn_sync_status = 'syncing' 
  OR psn_sync_status = 'cancelling'
  OR xbox_sync_status = 'syncing' 
  OR xbox_sync_status = 'cancelling'
  OR steam_sync_status = 'syncing' 
  OR steam_sync_status = 'cancelling';

-- Also mark any pending sync logs as cancelled
UPDATE psn_sync_logs 
SET status = 'cancelled', completed_at = NOW()
WHERE status IN ('pending', 'syncing');

UPDATE xbox_sync_logs 
SET status = 'cancelled', completed_at = NOW()
WHERE status IN ('pending', 'syncing');

UPDATE steam_sync_logs 
SET status = 'cancelled', completed_at = NOW()
WHERE status IN ('pending', 'syncing');