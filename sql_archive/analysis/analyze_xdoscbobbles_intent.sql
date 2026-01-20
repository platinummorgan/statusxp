-- Investigate what xdoscbobbles was trying to do with the duplicate account

-- Compare game data between the two accounts
SELECT 
  'ACCOUNT 1 (ojjm11@outlook.com - Main)' as account,
  platform_id,
  COUNT(DISTINCT game_title_id) as unique_games,
  SUM(statusxp_effective) as total_xp,
  MIN(created_at) as first_game_added,
  MAX(updated_at) as last_updated
FROM user_games
WHERE user_id = 'b23e206a-02d1-4920-b1ee-61ee44583518'
GROUP BY platform_id

UNION ALL

SELECT 
  'ACCOUNT 2 (oscarmargan20@gmail.com - Duplicate)' as account,
  platform_id,
  COUNT(DISTINCT game_title_id) as unique_games,
  SUM(statusxp_effective) as total_xp,
  MIN(created_at) as first_game_added,
  MAX(updated_at) as last_updated
FROM user_games
WHERE user_id = 'c5ff31aa-8572-441a-ab09-22accd4c979b'
GROUP BY platform_id
ORDER BY account, platform_id;

-- Check if there are any overlapping games (same game on both accounts)
SELECT 
  gt.name as game_name,
  ug1.platform_id,
  ug1.statusxp_effective as account1_xp,
  ug2.statusxp_effective as account2_xp,
  ug1.completion_percent as account1_completion,
  ug2.completion_percent as account2_completion
FROM user_games ug1
JOIN user_games ug2 ON ug1.game_title_id = ug2.game_title_id AND ug1.platform_id = ug2.platform_id
JOIN game_titles gt ON gt.id = ug1.game_title_id
WHERE ug1.user_id = 'b23e206a-02d1-4920-b1ee-61ee44583518'
  AND ug2.user_id = 'c5ff31aa-8572-441a-ab09-22accd4c979b'
ORDER BY gt.name;

-- Check recent sync/activity on both accounts
SELECT 
  'Account 1 (Main)' as account,
  email,
  last_psn_sync_at,
  last_xbox_sync_at,
  last_steam_sync_at,
  created_at as account_created
FROM profiles p
JOIN auth.users au ON au.id = p.id
WHERE p.id = 'b23e206a-02d1-4920-b1ee-61ee44583518'

UNION ALL

SELECT 
  'Account 2 (Duplicate)' as account,
  email,
  last_psn_sync_at,
  last_xbox_sync_at,
  last_steam_sync_at,
  created_at as account_created
FROM profiles p
JOIN auth.users au ON au.id = p.id
WHERE p.id = 'c5ff31aa-8572-441a-ab09-22accd4c979b';
