-- ============================================================================
-- Fix leaderboard with EFFICIENT calculation (no timeout)
-- ============================================================================

TRUNCATE TABLE leaderboard_cache;

-- Calculate for each user individually (much faster)
INSERT INTO leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
SELECT
  ua.user_id,
  SUM(calc.statusxp_effective)::bigint as total_statusxp,
  COUNT(DISTINCT (calc.platform_id, calc.platform_game_id))::integer as total_game_entries,
  NOW() as last_updated
FROM (
  -- Get unique users first
  SELECT DISTINCT user_id FROM user_achievements
) ua
CROSS JOIN LATERAL calculate_statusxp_with_stacks(ua.user_id) calc
INNER JOIN profiles p ON p.id = ua.user_id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id
HAVING SUM(calc.statusxp_effective) > 0;

-- Verify
SELECT COUNT(*) as users_updated FROM leaderboard_cache;

-- Your score
SELECT 
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
