-- Check DanyGT37's profile settings
SELECT 
  id,
  psn_online_id,
  show_on_leaderboard,
  last_psn_sync_at
FROM profiles 
WHERE id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check their PSN game data
SELECT COUNT(*) as game_count
FROM user_games 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check their platinum count
SELECT COUNT(*) as platinum_count
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND a.is_platinum = true;

-- Check what the refresh function is actually selecting
SELECT 
  p.id as user_id,
  p.psn_online_id as display_name,
  p.psn_avatar_url as avatar_url,
  COUNT(DISTINCT CASE WHEN a.is_platinum = true THEN ua.id END) as platinum_count,
  COUNT(DISTINCT ug.game_title_id) as total_games
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id
WHERE p.id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND p.show_on_leaderboard = true
  AND p.psn_account_id IS NOT NULL
GROUP BY p.id, p.psn_online_id, p.psn_avatar_url;
