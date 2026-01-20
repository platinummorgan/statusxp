-- Clear stale PSN syntax errors
UPDATE profiles 
SET psn_sync_error = NULL,
    psn_sync_status = 'success'
WHERE psn_sync_error LIKE '%Missing catch or finally after try%' 
   OR psn_sync_error LIKE '%catch%' 
   OR psn_sync_error LIKE '%finally%' 
   OR psn_sync_error LIKE '%try%'
   OR psn_sync_error LIKE '%syntax%';

-- Check which users had PSN syntax errors cleared
SELECT id, psn_sync_status, psn_sync_error, last_psn_sync_at 
FROM profiles 
WHERE psn_sync_error IS NOT NULL 
   OR psn_sync_status = 'error'
LIMIT 10;