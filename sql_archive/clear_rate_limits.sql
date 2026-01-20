-- Clear rate limits for all users
-- This removes sync history and resets daily sync counts

-- Option 1: Clear ALL sync history (removes all rate limit tracking)
DELETE FROM user_sync_history;

-- Option 2: Clear rate limits for specific user
-- DELETE FROM user_sync_history 
-- WHERE user_id = 'USER_ID_HERE';

-- Option 3: Clear only recent syncs (last 24 hours) for all users
-- DELETE FROM user_sync_history 
-- WHERE synced_at > NOW() - INTERVAL '24 hours';

-- Verify sync history is cleared
SELECT COUNT(*) as remaining_sync_records 
FROM user_sync_history;

-- Check if users have any remaining rate limits
SELECT 
  u.id,
  u.psn_online_id,
  u.xbox_gamertag,
  COUNT(h.id) as sync_count_last_24h
FROM profiles u
LEFT JOIN user_sync_history h ON h.user_id = u.id 
  AND h.synced_at > NOW() - INTERVAL '24 hours'
GROUP BY u.id, u.psn_online_id, u.xbox_gamertag
HAVING COUNT(h.id) > 0
ORDER BY sync_count_last_24h DESC
LIMIT 10;
