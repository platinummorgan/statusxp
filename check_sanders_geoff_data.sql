-- Check sanders.geoff (Robo Ripper) data
SELECT 
  'user_achievements' as table_name,
  COUNT(*) as record_count
FROM user_achievements
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889'
UNION ALL
SELECT 
  'user_progress' as table_name,
  COUNT(*) as record_count
FROM user_progress
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889'
UNION ALL
SELECT 
  'user_games' as table_name,
  COUNT(*) as record_count
FROM user_games
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889'
UNION ALL
SELECT 
  'leaderboard_cache' as table_name,
  COUNT(*) as record_count
FROM leaderboard_cache
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889';

-- Check leaderboard cache value
SELECT 
  total_statusxp,
  total_game_entries,
  last_updated
FROM leaderboard_cache
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889';

-- Check user_games breakdown by platform
SELECT 
  platform,
  COUNT(*) as game_count,
  SUM(achievements_unlocked) as total_achievements
FROM user_games
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889'
GROUP BY platform;
