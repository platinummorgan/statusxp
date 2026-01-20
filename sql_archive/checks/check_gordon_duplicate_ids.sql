-- Check if duplicate games have different game_title_id
SELECT 
  gt.name,
  COUNT(DISTINCT ug.game_title_id) as unique_game_ids,
  COUNT(*) as total_entries,
  SUM(ug.xbox_current_gamerscore) as total_gs,
  STRING_AGG(DISTINCT ug.game_title_id::text, ', ') as game_ids
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
INNER JOIN platforms pl ON ug.platform_id = pl.id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND pl.code = 'XBOXONE'
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY total_gs DESC
LIMIT 10;
