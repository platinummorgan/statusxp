-- Check what data is in user_progress for your games
-- This will show us if current_score/total_score are populated

-- Your user ID
\set user_id '4bfa2583-9d76-4ff0-9a85-ba96e9cb82bb'

-- Check user_progress table for all your games
SELECT 
  up.platform_id,
  p.code as platform_name,
  up.platform_game_id,
  g.name as game_name,
  up.current_score,
  up.total_score,
  up.achievements_earned,
  up.achievements_total
FROM user_progress up
LEFT JOIN platforms p ON p.id = up.platform_id
LEFT JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = '4bfa2583-9d76-4ff0-9a85-ba96e9cb82bb'
ORDER BY p.code, g.name
LIMIT 50;

-- Check StatusXP calculation for a few games
SELECT 
  ua.platform_id,
  ua.platform_game_id,
  COUNT(*) as achievements_earned,
  SUM(a.base_status_xp) as total_statusxp
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '4bfa2583-9d76-4ff0-9a85-ba96e9cb82bb'
  AND a.include_in_score = true
GROUP BY ua.platform_id, ua.platform_game_id
ORDER BY total_statusxp DESC
LIMIT 20;

-- Check what get_user_grouped_games returns for you
SELECT * FROM get_user_grouped_games('4bfa2583-9d76-4ff0-9a85-ba96e9cb82bb')
LIMIT 5;
