SELECT psn_sync_status, psn_sync_error, psn_sync_progress, last_psn_sync_at
FROM profiles
WHERE psn_account_id IS NOT NULL
ORDER BY updated_at DESC
LIMIT 1;
