-- Check Gordon's Xbox games and gamerscore
SELECT 
  gt.name as game_name,
  pl.code as platform,
  ug.xbox_current_gamerscore,
  ug.xbox_max_gamerscore,
  ug.updated_at
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
INNER JOIN platforms pl ON ug.platform_id = pl.id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
ORDER BY ug.xbox_current_gamerscore DESC
LIMIT 20;

-- Also check for any duplicates
SELECT 
  gt.name,
  COUNT(*) as count,
  SUM(ug.xbox_current_gamerscore) as total_gs
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
INNER JOIN platforms pl ON ug.platform_id = pl.id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
