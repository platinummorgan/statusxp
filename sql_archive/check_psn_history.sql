-- Check if there's any PSN leaderboard history
SELECT 
  COUNT(*) as total_records,
  MIN(snapshot_at) as oldest_snapshot,
  MAX(snapshot_at) as newest_snapshot,
  COUNT(DISTINCT user_id) as unique_users
FROM psn_leaderboard_history;

-- Check if there are snapshots older than 1 hour
SELECT 
  COUNT(*) as records_older_than_1hr,
  MAX(snapshot_at) as most_recent_old_snapshot
FROM psn_leaderboard_history
WHERE snapshot_at < now() - INTERVAL '1 hour';

-- Show sample of recent history
SELECT user_id, rank, snapshot_at, platinum_count
FROM psn_leaderboard_history
ORDER BY snapshot_at DESC
LIMIT 10;
