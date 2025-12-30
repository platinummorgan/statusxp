-- Check what leaderboard is calculating
SELECT 
  username,
  psn_online_id,
  -- Check if there's a cached statusxp column
  (SELECT column_name FROM information_schema.columns WHERE table_name = 'profiles' AND column_name LIKE '%statusxp%') as statusxp_columns
FROM profiles
WHERE username = 'Dex-Morgan';

-- Also check the actual leaderboard view/function
SELECT 
  p.username,
  COUNT(DISTINCT ug.id) as game_count,
  COUNT(DISTINCT ua.id) as achievement_count,
  -- Try to find how statusxp is calculated in views
  (SELECT base_statusxp FROM profiles WHERE id = p.id) as base_statusxp_if_exists
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN user_achievements ua ON ua.user_id = p.id
WHERE p.username = 'Dex-Morgan'
GROUP BY p.id, p.username;
