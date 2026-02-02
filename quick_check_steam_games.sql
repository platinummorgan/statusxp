-- Quick check for Steam games in user_games view
-- This is what the app queries

SELECT 
  'Steam games count' as metric,
  COUNT(*) as value
FROM user_games
WHERE platform_id = 4;  -- Steam is platform_id 4

-- Show sample Steam games
SELECT 
  game_title,
  platform_id,
  earned_trophies,
  total_trophies,
  completion_percent,
  last_played_at
FROM user_games
WHERE platform_id = 4
ORDER BY last_played_at DESC NULLS LAST
LIMIT 10;

-- Check raw user_progress table
SELECT 
  'user_progress Steam games' as source,
  COUNT(*) as count
FROM user_progress  
WHERE platform_id = 4;

-- Check platforms table mapping
SELECT id, code, name 
FROM platforms 
WHERE id IN (1, 2, 4, 5, 10, 11, 12)
ORDER BY id;
