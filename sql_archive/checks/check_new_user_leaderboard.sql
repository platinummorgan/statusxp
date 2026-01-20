-- Find the most recent PSN sync (should be the new user)
SELECT 
  p.id as user_id,
  p.psn_online_id,
  p.last_psn_sync_at,
  psl.status,
  psl.completed_at
FROM profiles p
LEFT JOIN psn_sync_logs psl ON psl.user_id = p.id
WHERE p.last_psn_sync_at IS NOT NULL
ORDER BY p.last_psn_sync_at DESC
LIMIT 5;

-- Check if that user is in PSN leaderboard cache
-- Replace USER_ID below with the ID from above query
SELECT * FROM psn_leaderboard_cache 
WHERE user_id = 'REPLACE_WITH_USER_ID_FROM_ABOVE';

-- If not found, refresh the cache
SELECT refresh_psn_leaderboard_cache();

-- Check all recent entries in cache
SELECT * FROM psn_leaderboard_cache 
ORDER BY updated_at DESC
LIMIT 10;
