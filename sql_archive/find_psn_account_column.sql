-- Check which table has psn_account_id column
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN ('psn_account_id', 'user_id', 'id')
  AND table_name IN ('user_sync_status', 'user_stats', 'user_profile_settings', 'psn_user_trophy_profile')
ORDER BY table_name, ordinal_position;
