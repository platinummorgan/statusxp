-- Reset PSN sync status for Dexmorgan6981 to trigger re-sync
-- This will allow testing the fixed PSN sync code

-- After this runs, trigger sync on phone and check if achievements are written

UPDATE profiles
SET 
  last_psn_sync_at = NULL,
  psn_sync_status = NULL,
  psn_sync_progress = 0,
  psn_sync_error = NULL
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
RETURNING id, psn_username, last_psn_sync_at, psn_sync_status;

-- Check current state before reset
SELECT 
  'Before Reset' as status,
  psn_username,
  last_psn_sync_at,
  psn_sync_status,
  psn_sync_progress,
  psn_sync_error
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;
