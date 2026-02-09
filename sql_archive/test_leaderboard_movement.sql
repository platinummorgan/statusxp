-- Test queries for leaderboard rank movement feature

-- 1. Get leaderboard with movement indicators (top 100)
SELECT 
  current_rank,
  display_name,
  total_statusxp,
  previous_rank,
  rank_change,
  CASE 
    WHEN is_new THEN '🆕 NEW'
    WHEN rank_change > 0 THEN '🟢 ▲' || rank_change
    WHEN rank_change < 0 THEN '🔴 ▼' || ABS(rank_change)
    ELSE '➖ No change'
  END as movement_indicator
FROM get_leaderboard_with_movement(100, 0)
ORDER BY current_rank;

-- 2. Check specific user's rank movement (ZFR_RaFa example)
SELECT 
  current_rank,
  display_name,
  total_statusxp,
  previous_rank,
  rank_change,
  CASE 
    WHEN is_new THEN 'NEW TO LEADERBOARD'
    WHEN rank_change > 0 THEN 'MOVED UP ' || rank_change || ' SPOTS'
    WHEN rank_change < 0 THEN 'MOVED DOWN ' || ABS(rank_change) || ' SPOTS'
    ELSE 'NO CHANGE'
  END as status
FROM get_leaderboard_with_movement(1000, 0)
WHERE user_id = 'ff194d87-37d5-4219-a71d-a52bb81709e6';

-- 3. View leaderboard snapshot history
SELECT 
  snapshot_at,
  COUNT(*) as users_on_leaderboard,
  MIN(rank) as top_rank,
  MAX(rank) as lowest_rank,
  MAX(total_statusxp) as highest_score
FROM leaderboard_history
GROUP BY snapshot_at
ORDER BY snapshot_at DESC
LIMIT 10;

-- 4. Track a specific user's rank over time
SELECT 
  snapshot_at,
  rank,
  total_statusxp,
  LAG(rank) OVER (ORDER BY snapshot_at) as previous_rank,
  rank - LAG(rank) OVER (ORDER BY snapshot_at) as rank_change
FROM leaderboard_history
WHERE user_id = 'ff194d87-37d5-4219-a71d-a52bb81709e6'
ORDER BY snapshot_at DESC
LIMIT 30;

-- 5. See biggest movers (up and down) since last snapshot
WITH current_ranks AS (
  SELECT 
    user_id,
    ROW_NUMBER() OVER (ORDER BY total_statusxp DESC) as current_rank,
    total_statusxp
  FROM leaderboard_cache lc
  JOIN profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true
    AND lc.total_statusxp > 0
),
latest_snapshot AS (
  SELECT DISTINCT ON (user_id)
    user_id,
    rank as previous_rank
  FROM leaderboard_history
  WHERE snapshot_at = (SELECT MAX(snapshot_at) FROM leaderboard_history)
  ORDER BY user_id
)
SELECT 
  p.display_name,
  cr.current_rank,
  ls.previous_rank,
  (ls.previous_rank - cr.current_rank) as rank_change,
  cr.total_statusxp
FROM current_ranks cr
JOIN profiles p ON p.id = cr.user_id
LEFT JOIN latest_snapshot ls ON ls.user_id = cr.user_id
WHERE ls.previous_rank IS NOT NULL
ORDER BY (ls.previous_rank - cr.current_rank) DESC
LIMIT 20;

-- 6. Manually create a snapshot (for testing)
-- SELECT snapshot_leaderboard();

-- 7. View raw leaderboard history data
SELECT 
  lh.snapshot_at,
  lh.rank,
  p.display_name,
  lh.total_statusxp
FROM leaderboard_history lh
JOIN profiles p ON p.id = lh.user_id
ORDER BY lh.snapshot_at DESC, lh.rank
LIMIT 50;
