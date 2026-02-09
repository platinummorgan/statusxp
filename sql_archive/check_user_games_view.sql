-- Check the user_games view structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
ORDER BY ordinal_position;

-- Check how many records are in user_games for a user
SELECT 
  COUNT(*) as total_games,
  COUNT(CASE WHEN platform_id = 1 THEN 1 END) as ps5_games,
  COUNT(CASE WHEN platform_id = 2 THEN 1 END) as ps4_games,
  COUNT(CASE WHEN platform_id = 4 THEN 1 END) as steam_games,
  COUNT(CASE WHEN platform_id = 11 THEN 1 END) as xboxone_games
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
