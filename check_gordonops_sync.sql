-- Check gordonops sync status and trophy data
SELECT 
  username,
  psn_online_id,
  last_psn_sync_at,
  psn_sync_status,
  psn_sync_error,
  psn_sync_progress
FROM profiles
WHERE id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';
