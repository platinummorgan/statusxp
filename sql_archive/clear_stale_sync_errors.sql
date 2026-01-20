-- Clear stale Steam sync syntax errors
UPDATE profiles 
SET steam_sync_error = NULL 
WHERE steam_sync_error LIKE '%Missing catch or finally after try%' 
   OR steam_sync_error LIKE '%catch%' 
   OR steam_sync_error LIKE '%finally%' 
   OR steam_sync_error LIKE '%try%';

-- Also clear PSN sync syntax errors if any
UPDATE profiles 
SET psn_sync_error = NULL 
WHERE psn_sync_error LIKE '%Missing catch or finally after try%' 
   OR psn_sync_error LIKE '%catch%' 
   OR psn_sync_error LIKE '%finally%' 
   OR psn_sync_error LIKE '%try%';

-- Check current sync status after clearing
SELECT id, steam_sync_status, steam_sync_error, psn_sync_status, psn_sync_error 
FROM profiles 
WHERE steam_sync_error IS NOT NULL 
   OR psn_sync_error IS NOT NULL 
LIMIT 10;