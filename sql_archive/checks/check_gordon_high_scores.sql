-- Find games that might be causing the 50k difference
-- Look for games with suspiciously high gamerscore
SELECT 
  gt.name,
  ug.xbox_current_gamerscore,
  ug.xbox_max_gamerscore,
  ug.updated_at,
  CASE 
    WHEN ug.xbox_current_gamerscore > 5000 THEN 'Suspiciously high'
    WHEN ug.xbox_current_gamerscore = ug.xbox_max_gamerscore AND ug.xbox_max_gamerscore > 3000 THEN 'Perfect completion of high-value game'
    ELSE 'Normal'
  END as flag
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
INNER JOIN platforms pl ON ug.platform_id = pl.id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 3000
ORDER BY ug.xbox_current_gamerscore DESC;
