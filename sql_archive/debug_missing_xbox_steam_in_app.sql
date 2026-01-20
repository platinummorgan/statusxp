-- Check if your Xbox and Steam games are in user_games view
SELECT 
  platform_id,
  CASE platform_id
    WHEN 1 THEN 'PSN'
    WHEN 5 THEN 'Steam'
    WHEN 10 THEN 'Xbox360'
    WHEN 11 THEN 'XboxOne'
    WHEN 12 THEN 'XboxSeriesX'
  END as platform_name,
  COUNT(*) as game_count
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_id
ORDER BY platform_id;

-- Test the exact query the app uses
SELECT 
  id,
  user_id,
  game_title_id,
  platform_id,
  total_trophies,
  earned_trophies
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
LIMIT 5;

-- Check if game_titles join works
SELECT 
  ug.id,
  ug.platform_id,
  gt.name,
  gt.cover_url
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id IN (10, 11, 12)
LIMIT 5;
