-- Investigate the StatusXP_Demo account created for Apple Testing

-- Full details of the demo account
SELECT 
  p.id,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  p.steam_id,
  p.created_at,
  p.updated_at,
  au.email,
  au.created_at as auth_created_at,
  lc.total_statusxp,
  lc.total_game_entries
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE au.email = 'demo@statusxp.test';

-- Check the demo account's games
SELECT 
  ug.game_title_id,
  gt.name,
  ug.platform_id,
  ug.statusxp_effective,
  ug.completion_percentage,
  ug.is_completed
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '3287df01-36aa-41b4-8b0a-a0a49cf54276'
ORDER BY ug.statusxp_effective DESC;

-- Check if there are ANY other test/demo accounts
SELECT 
  p.id,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  au.email,
  lc.total_statusxp
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE au.email LIKE '%test%' 
   OR au.email LIKE '%demo%'
   OR p.psn_online_id LIKE '%test%'
   OR p.psn_online_id LIKE '%demo%'
   OR p.xbox_gamertag LIKE '%test%'
   OR p.xbox_gamertag LIKE '%demo%';
