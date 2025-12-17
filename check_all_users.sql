-- Verify which user we're querying and check for multiple accounts

-- 1. Show ALL user profiles
SELECT 
  id,
  username,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  created_at
FROM profiles
ORDER BY created_at DESC;

-- 2. Count user_games for EACH user
SELECT 
  p.username,
  p.psn_online_id,
  COUNT(DISTINCT ug.game_title_id) as total_games
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
GROUP BY p.id, p.username, p.psn_online_id
ORDER BY total_games DESC;

-- 3. Check ALL user_games entries (not filtered by user)
SELECT COUNT(*) as total_user_games_all_users
FROM user_games;

-- 4. Show game count by user_id
SELECT 
  user_id,
  COUNT(*) as games
FROM user_games
GROUP BY user_id
ORDER BY games DESC;
