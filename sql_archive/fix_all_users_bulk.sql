-- FAST FIX: Bulk update all users' current_score with calculated StatusXP
-- Uses a single UPDATE with subquery instead of looping

-- Step 1: Update all user_progress.current_score in one query
UPDATE user_progress up
SET current_score = subquery.statusxp_effective
FROM (
  SELECT 
    cx.user_id,
    cx.platform_id,
    cx.platform_game_id,
    cx.statusxp_effective
  FROM user_progress up_inner
  CROSS JOIN LATERAL calculate_statusxp_with_stacks(up_inner.user_id) cx
  WHERE cx.platform_id = up_inner.platform_id
    AND cx.platform_game_id = up_inner.platform_game_id
) subquery
WHERE up.user_id = subquery.user_id
  AND up.platform_id = subquery.platform_id
  AND up.platform_game_id = subquery.platform_game_id;

-- Step 2: Refresh leaderboard cache
SELECT refresh_statusxp_leaderboard();

-- Step 3: Verify fix
SELECT 
  'AFTER FIX - user_progress sum' as status,
  SUM(current_score) as value
FROM user_progress
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889'
UNION ALL
SELECT 
  'AFTER FIX - leaderboard_cache' as status,
  total_statusxp as value
FROM leaderboard_cache
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889';
