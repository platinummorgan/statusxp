-- Deep investigation for user with syncs but 0 achievements
-- Replace USER_NAME with username

-- 1. Check if they have any games in user_progress (should have some if syncs ran)
SELECT 
  platform_id,
  COUNT(*) as game_count,
  SUM(achievements_earned) as total_earned,
  SUM(total_achievements) as total_possible,
  SUM(current_score) as sum_current_score
FROM user_progress
WHERE user_id = (SELECT id FROM profiles WHERE username = 'USER_NAME')
GROUP BY platform_id;

-- 2. Check sync status in profiles
SELECT 
  username,
  psn_sync_status,
  last_psn_sync_at,
  xbox_sync_status,
  last_xbox_sync_at,
  steam_sync_status,
  last_steam_sync_at
FROM profiles
WHERE username = 'USER_NAME';

-- 3. Check if user_achievements is completely empty
SELECT COUNT(*) as achievement_count
FROM user_achievements
WHERE user_id = (SELECT id FROM profiles WHERE username = 'USER_NAME');

-- 4. Check if achievements exist in achievements table for their games
SELECT 
  a.platform_id,
  COUNT(*) as achievement_definitions
FROM user_progress up
JOIN achievements a ON 
  a.platform_id = up.platform_id 
  AND a.platform_game_id = up.platform_game_id
WHERE up.user_id = (SELECT id FROM profiles WHERE username = 'USER_NAME')
GROUP BY a.platform_id;

-- 5. Check for sync errors in sync logs
SELECT *
FROM xbox_sync_logs
WHERE user_id = (SELECT id FROM profiles WHERE username = 'USER_NAME')
ORDER BY started_at DESC
LIMIT 5;
