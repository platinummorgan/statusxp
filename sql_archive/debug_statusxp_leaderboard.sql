-- Check StatusXP leaderboard calculation

-- 1. What does the leaderboard_cache view show for you?
SELECT 
  user_id,
  display_name,
  statusxp,
  achievement_count,
  platform
FROM leaderboard_cache
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'  -- XxlmThumperxX
ORDER BY statusxp DESC;

-- 2. Recalculate what it SHOULD be
SELECT 
  'Correct total' as source,
  SUM(up.current_score) as statusxp
FROM user_progress up
WHERE up.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';

-- 3. Check the leaderboard_cache view definition
SELECT definition
FROM pg_views
WHERE viewname = 'leaderboard_cache';

-- 4. Check how many rows per user in leaderboard_cache
SELECT 
  user_id,
  COUNT(*) as rows_in_cache,
  SUM(statusxp) as total_statusxp
FROM leaderboard_cache
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
GROUP BY user_id;
