-- Check platinum achievements in user_achievements table for DaHead22
SELECT 
  gt.name as game_name,
  a.name as achievement_name,
  a.psn_trophy_type,
  ua.created_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
JOIN profiles p ON p.id = ua.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND a.psn_trophy_type = 'platinum'
  AND a.platform = 'psn'
ORDER BY ua.created_at DESC;
