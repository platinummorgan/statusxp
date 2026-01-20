-- Break down Gordon's gamerscore by Xbox platform
SELECT 
  pl.code as platform,
  pl.name as platform_name,
  SUM(ug.xbox_current_gamerscore) as gamerscore,
  COUNT(DISTINCT ug.game_title_id) as games_count
FROM user_games ug
INNER JOIN platforms pl ON ug.platform_id = pl.id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
GROUP BY pl.code, pl.name
ORDER BY gamerscore DESC;
