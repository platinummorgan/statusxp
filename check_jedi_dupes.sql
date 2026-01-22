-- Check Jedi games for your user
SELECT 
  game_title,
  platform_id,
  game_title_id,
  completion_percent,
  earned_trophies,
  total_trophies,
  last_played_at,
  last_trophy_earned_at
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND LOWER(game_title) LIKE '%jedi%'
ORDER BY last_trophy_earned_at DESC;
