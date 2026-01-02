-- Check user_sync_status columns (likely has psn_account_id)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_sync_status'
ORDER BY ordinal_position;
