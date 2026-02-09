-- Verify leaderboard movement tracking is working

-- 1. Check if table exists and has data
SELECT 
  COUNT(*) as total_snapshots,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(DISTINCT snapshot_at) as snapshot_count,
  MIN(snapshot_at) as first_snapshot,
  MAX(snapshot_at) as latest_snapshot
FROM leaderboard_history;

-- 2. View latest snapshot details
SELECT 
  snapshot_at,
  COUNT(*) as users_in_snapshot,
  MIN(rank) as top_rank,
  MAX(rank) as lowest_rank,
  MAX(total_statusxp) as highest_score,
  MIN(total_statusxp) as lowest_score
FROM leaderboard_history
WHERE snapshot_at = (SELECT MAX(snapshot_at) FROM leaderboard_history)
GROUP BY snapshot_at;

-- 3. Test the new function - get top 20 with movement
SELECT 
  current_rank,
  display_name,
  total_statusxp,
  previous_rank,
  rank_change,
  is_new,
  CASE 
    WHEN is_new THEN '🆕 NEW'
    WHEN rank_change > 0 THEN '🟢 ▲' || rank_change
    WHEN rank_change < 0 THEN '🔴 ▼' || ABS(rank_change)
    ELSE '➖'
  END as movement_indicator
FROM get_leaderboard_with_movement(20, 0)
ORDER BY current_rank;

-- 4. Check if cron job is scheduled
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active,
  jobname
FROM cron.job 
WHERE jobname = 'daily-leaderboard-snapshot';

-- 5. View sample of historical data
SELECT 
  lh.rank,
  p.display_name,
  lh.total_statusxp,
  lh.snapshot_at
FROM leaderboard_history lh
JOIN profiles p ON p.id = lh.user_id
ORDER BY lh.snapshot_at DESC, lh.rank
LIMIT 30;
