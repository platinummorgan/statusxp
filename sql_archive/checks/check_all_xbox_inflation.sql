-- Check ALL Xbox users for duplicate inflation
SELECT 
  p.username,
  p.id as user_id,
  SUM(ug.xbox_current_gamerscore) as inflated_gs,
  SUM(max_scores.max_gs) as correct_gs,
  SUM(ug.xbox_current_gamerscore) - SUM(max_scores.max_gs) as difference
FROM profiles p
INNER JOIN user_games ug ON p.id = ug.user_id
INNER JOIN platforms pl ON ug.platform_id = pl.id
INNER JOIN (
  SELECT 
    ug2.user_id,
    gt.name as game_name,
    MAX(ug2.xbox_current_gamerscore) as max_gs
  FROM user_games ug2
  INNER JOIN game_titles gt ON ug2.game_title_id = gt.id
  INNER JOIN platforms pl2 ON ug2.platform_id = pl2.id
  WHERE pl2.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  GROUP BY ug2.user_id, gt.name
) max_scores ON p.id = max_scores.user_id
WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
GROUP BY p.username, p.id
HAVING SUM(ug.xbox_current_gamerscore) - SUM(max_scores.max_gs) > 0
ORDER BY difference DESC;
