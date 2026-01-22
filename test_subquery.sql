-- Test if the achievement date query works for a specific Steam game
SELECT 
  ug.game_title,
  ug.last_trophy_earned_at,
  ug.last_played_at,
  (
    SELECT MAX(ua.earned_at) 
    FROM user_achievements ua
    WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
      AND ua.platform_id = ug.platform_id
      AND ua.platform_game_id = g.platform_game_id
  ) as max_achievement_date,
  g.platform_game_id
FROM user_games ug
LEFT JOIN games g ON g.platform_id = ug.platform_id 
  AND g.name = ug.game_title
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id = 4
  AND ug.game_title = 'The Room Two'
LIMIT 1;
