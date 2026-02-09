-- Check user_progress table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_progress' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if there's a relationship we can use
SELECT 
  ug.game_title,
  ug.platform_id,
  ug.game_title_id,
  ua.platform_game_id,
  COUNT(*) as achievement_count
FROM user_games ug
JOIN user_achievements ua ON ua.user_id = ug.user_id 
  AND ua.platform_id = ug.platform_id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY ug.game_title, ug.platform_id, ug.game_title_id, ua.platform_game_id
LIMIT 5;
