-- Reset Thumper's sync status to trigger fresh sync with IGDB validation
-- User ID: 8fef7fd4-581d-4ef9-9d48-482eff31c69d

-- 1. Cancel any active PSN sync logs
UPDATE psn_sync_logs
SET 
  status = 'cancelled',
  error_message = 'Cancelled to enable IGDB platform validation',
  completed_at = NOW()
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND status = 'in_progress';

-- 2. Reset sync status in profiles
UPDATE profiles
SET 
  psn_sync_status = 'never_synced',
  psn_sync_error = NULL,
  psn_sync_progress = 0
WHERE id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';

-- 3. Verify reset
SELECT 
  id,
  display_name,
  psn_online_id,
  psn_sync_status,
  psn_sync_progress,
  last_psn_sync_at
FROM profiles
WHERE id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';
