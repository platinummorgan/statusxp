-- Check if Ghost of Yōtei platinum achievement exists in user_achievements
SELECT 
  gt.name as game_name,
  a.name as achievement_name,
  a.psn_trophy_type,
  a.platform,
  ua.created_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
JOIN profiles p ON p.id = ua.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND gt.name = 'Ghost of Yōtei'
  AND a.psn_trophy_type = 'platinum';
