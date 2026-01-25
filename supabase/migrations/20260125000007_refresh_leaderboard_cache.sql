-- Refresh leaderboard_cache with correct StatusXP totals

BEGIN;

-- Clear the stale cache
TRUNCATE leaderboard_cache;

-- Repopulate with correct totals from recalculated user_progress
INSERT INTO leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
SELECT 
  up.user_id,
  SUM(up.current_score)::bigint as total_statusxp,
  COUNT(DISTINCT up.platform_game_id) as total_game_entries,
  NOW() as last_updated
FROM user_progress up
WHERE up.current_score > 0
GROUP BY up.user_id;

COMMIT;

-- Verify refresh worked
SELECT 
  COUNT(*) as users_on_leaderboard,
  SUM(total_statusxp) as total_statusxp_all_users,
  MAX(total_statusxp) as max_user_statusxp,
  AVG(total_statusxp) as avg_statusxp
FROM leaderboard_cache;

-- Show XxlmThumperxX's corrected ranking
SELECT 
  ROW_NUMBER() OVER (ORDER BY total_statusxp DESC) as rank,
  user_id,
  total_statusxp,
  total_game_entries
FROM leaderboard_cache
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';
