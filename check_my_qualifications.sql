-- Check if I should have these achievements
SELECT 
  -- No Life Great Life: 2500+ achievements
  (SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
  (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') as total_achievements,
  
  -- Welcome PC Grind: At least 1 Steam achievement
  (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 3) as steam_games,
  
  -- Triforce: Achievements on all 3 platforms
  (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 1) as psn_games,
  (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 2) as xbox_games;
