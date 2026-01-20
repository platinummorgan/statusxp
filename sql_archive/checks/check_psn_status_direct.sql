-- Quick check your PSN sync status directly from database
SELECT 
    id,
    psn_sync_status,
    psn_sync_progress,
    psn_sync_error,
    last_psn_sync_at,
    psn_account_id
FROM profiles 
WHERE psn_account_id IS NOT NULL 
ORDER BY last_psn_sync_at DESC
LIMIT 5;