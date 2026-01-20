-- Check PSN sync status
SELECT
  psn_sync_status,
  psn_sync_progress,
  psn_sync_error,
  last_psn_sync_at,
  updated_at
FROM profiles
LIMIT 5;
