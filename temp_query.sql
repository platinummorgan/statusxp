SELECT 
  id,
  status,
  games_processed,
  games_total,
  error_message,
  started_at,
  completed_at
FROM psn_sync_log 
ORDER BY started_at DESC 
LIMIT 5;
