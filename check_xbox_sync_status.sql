-- Check current Xbox sync status
SELECT 
  id,
  xbox_sync_status,
  xbox_sync_progress,
  xbox_sync_error,
  xbox_user_hash,
  updated_at
FROM profiles
WHERE xbox_user_hash IS NOT NULL
ORDER BY updated_at DESC
LIMIT 5;

-- Check latest Xbox sync log
SELECT 
  id,
  user_id,
  status,
  games_processed,
  array_length(games_processed_ids, 1) as processed_count,
  games_processed_ids,
  error_message,
  started_at,
  completed_at,
  created_at
FROM xbox_sync_logs
ORDER BY started_at DESC
LIMIT 5;
