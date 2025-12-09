-- Get a game that should have recent trophy activity
SELECT 
  ug.game_title_id,
  gt.name,
  ug.earned_trophies,
  (SELECT COUNT(*) FROM user_achievements ua 
   JOIN achievements a ON a.id = ua.achievement_id 
   WHERE a.game_title_id = ug.game_title_id 
   AND ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') as achievements_in_db,
  (SELECT MAX(ua.earned_at) FROM user_achievements ua
   JOIN achievements a ON a.id = ua.achievement_id
   WHERE a.game_title_id = ug.game_title_id
   AND ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') as last_trophy_earned
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.name LIKE '%METAL GEAR%'
LIMIT 1;
