-- Test if we can select the structure the app expects from user_games view
SELECT 
  id,
  user_id,
  game_title_id,
  platform_id,
  total_trophies,
  earned_trophies,
  has_platinum,
  completion_percent,
  bronze_trophies,
  silver_trophies,
  gold_trophies,
  platinum_trophies,
  last_played_at,
  last_trophy_earned_at
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 11
LIMIT 3;

-- Check if we have game names and covers in the view
SELECT 
  game_title,
  platform_id
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
LIMIT 5;
