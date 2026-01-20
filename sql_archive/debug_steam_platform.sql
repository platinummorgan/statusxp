-- Check platforms table
SELECT * FROM platforms;

-- Check how many Steam games are in user_games
SELECT 
  ug.platform_id,
  COUNT(*) as game_count,
  COUNT(DISTINCT ug.user_id) as user_count
FROM user_games ug
WHERE ug.platform_id = 3 OR ug.platform_id IS NULL
GROUP BY ug.platform_id;

-- Check a known Steam user (Dexmorgan6981)
SELECT 
  ug.platform_id,
  gt.name,
  COUNT(*) as count
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY ug.platform_id, gt.name
LIMIT 10;

-- Check achievements table platform field
SELECT DISTINCT platform FROM achievements WHERE platform LIKE '%steam%' LIMIT 5;
