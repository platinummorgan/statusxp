-- Check what we have now
SELECT 
  p.code as platform,
  COUNT(DISTINCT ug.game_title_id) as unique_games,
  COUNT(*) as total_user_game_records
FROM user_games ug
LEFT JOIN platforms p ON ug.platform_id = p.id
GROUP BY p.code
ORDER BY total_user_game_records DESC;

-- Check if there are any games that appear on multiple platforms
SELECT 
  gt.name,
  COUNT(*) as platform_count,
  STRING_AGG(p.code, ', ') as platforms
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
LEFT JOIN platforms p ON ug.platform_id = p.id
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY platform_count DESC
LIMIT 20;

-- Check A Plague Tale specifically
SELECT 
  gt.name,
  p.code as platform,
  ug.total_trophies,
  ug.earned_trophies,
  ug.completion_percent
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
LEFT JOIN platforms p ON ug.platform_id = p.id
WHERE gt.name LIKE '%Plague Tale%'
ORDER BY p.code;
