-- Check if you have Steam games in user_progress
SELECT 
  platform_id,
  COUNT(*) as game_count,
  SUM(achievements_earned) as total_achievements
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 5  -- Steam
GROUP BY platform_id;

-- Check if Steam games exist in games table
SELECT 
  COUNT(*) as steam_games_in_db
FROM games
WHERE platform_id = 5;

-- Check if you have any Steam user_achievements
SELECT 
  COUNT(*) as steam_achievements
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 5;

-- Try to get Steam games from the function
SELECT 
  name,
  (platforms[1]->>'code') as platform,
  (platforms[1]->>'earned_trophies')::int as earned,
  (platforms[1]->>'total_trophies')::int as total
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid)
WHERE (platforms[1]->>'code') = 'Steam'
LIMIT 10;
