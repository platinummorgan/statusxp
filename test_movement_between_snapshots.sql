-- Manual test to show rank movement between the two snapshots you just created
-- This simulates what the automatic function will show once snapshots are 1+ hour apart

WITH snapshot1 AS (
  SELECT 
    user_id,
    rank as old_rank,
    total_statusxp as old_score
  FROM leaderboard_history
  WHERE snapshot_at = '2026-02-02 14:25:30.384975+00'
),
snapshot2 AS (
  SELECT 
    user_id,
    rank as new_rank,
    total_statusxp as new_score
  FROM leaderboard_history
  WHERE snapshot_at = '2026-02-02 14:26:21.338286+00'
)
SELECT 
  s2.new_rank as current_rank,
  p.display_name,
  s2.new_score as current_statusxp,
  s1.old_rank as previous_rank,
  (s1.old_rank - s2.new_rank) as rank_change,
  (s2.new_score - s1.old_score) as score_change,
  CASE 
    WHEN s1.old_rank IS NULL THEN '🆕 NEW'
    WHEN s1.old_rank - s2.new_rank > 0 THEN '🟢 ▲' || (s1.old_rank - s2.new_rank)
    WHEN s1.old_rank - s2.new_rank < 0 THEN '🔴 ▼' || ABS(s1.old_rank - s2.new_rank)
    ELSE '➖ No change'
  END as movement_indicator
FROM snapshot2 s2
JOIN profiles p ON p.id = s2.user_id
LEFT JOIN snapshot1 s1 ON s1.user_id = s2.user_id
ORDER BY s2.new_rank
LIMIT 24;

-- Notice killjoy0124 gained 34 StatusXP points between snapshots!
-- (from 76740 to 76774)
