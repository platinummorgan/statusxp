-- Quick fix for just 2 users: You and sanders.geoff
-- Step 1: Fix your account
UPDATE user_progress up
SET current_score = cx.statusxp_effective
FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a') cx
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND up.platform_id = cx.platform_id
  AND up.platform_game_id = cx.platform_game_id;

-- Step 2: Fix sanders.geoff
UPDATE user_progress up
SET current_score = cx.statusxp_effective
FROM calculate_statusxp_with_stacks('ca9dc5a7-34a6-4a71-8659-d28da82de889') cx
WHERE up.user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889'
  AND up.platform_id = cx.platform_id
  AND up.platform_game_id = cx.platform_game_id;

-- Step 3: Manually update leaderboard_cache for just these 2 users
INSERT INTO leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
SELECT 
  up.user_id,
  SUM(up.current_score) as total_statusxp,
  COUNT(DISTINCT CONCAT(up.platform_id, '-', up.platform_game_id)) as total_game_entries,
  NOW() as last_updated
FROM user_progress up
WHERE up.user_id IN ('84b60ad6-cb2c-484f-8953-bf814551fd7a', 'ca9dc5a7-34a6-4a71-8659-d28da82de889')
GROUP BY up.user_id
ON CONFLICT (user_id) 
DO UPDATE SET
  total_statusxp = EXCLUDED.total_statusxp,
  total_game_entries = EXCLUDED.total_game_entries,
  last_updated = EXCLUDED.last_updated;

-- Verify both
SELECT 
  p.username as user, 
  lc.total_statusxp
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id IN ('84b60ad6-cb2c-484f-8953-bf814551fd7a', 'ca9dc5a7-34a6-4a71-8659-d28da82de889');
