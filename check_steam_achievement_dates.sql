-- Check if Steam games have achievement earned dates we can use
SELECT 
  g.name,
  up.last_played_at as current_last_played,
  MAX(ua.earned_at) as most_recent_achievement
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id 
  AND g.platform_game_id = up.platform_game_id
LEFT JOIN user_achievements ua ON ua.user_id = up.user_id
  AND ua.platform_id = up.platform_id
  AND ua.platform_game_id = up.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND up.platform_id = 4  -- Steam
GROUP BY g.name, up.last_played_at
ORDER BY most_recent_achievement DESC NULLS LAST
LIMIT 10;
