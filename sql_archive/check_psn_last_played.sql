-- Check PSN games - they should have real last_played dates
SELECT 
  g.name,
  up.last_played_at,
  up.platform_id
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id 
  AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND up.platform_id IN (1, 2, 5)  -- PS5, PS4, PS3
ORDER BY up.last_played_at DESC NULLS LAST
LIMIT 10;
