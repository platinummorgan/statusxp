-- Clear gordonops' PSN sync status so he can re-sync
UPDATE profiles
SET 
  last_psn_sync_at = NULL,
  psn_sync_status = NULL,
  psn_sync_progress = 0,
  psn_sync_error = NULL
WHERE username = 'gordonops';

-- Verify the reset
SELECT 
  username,
  psn_online_id,
  last_psn_sync_at,
  psn_sync_status,
  psn_sync_progress
FROM profiles
WHERE username = 'gordonops';
