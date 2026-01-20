-- Check Gordon's ACTUAL Xbox gamerscore (deduplicated)
SELECT 
  p.username,
  p.id as user_id,
  SUM(max_scores.max_gs) as actual_gamerscore
FROM profiles p
INNER JOIN (
  SELECT 
    ug.user_id,
    ug.game_title_id,
    MAX(ug.xbox_current_gamerscore) as max_gs
  FROM user_games ug
  INNER JOIN platforms pl ON ug.platform_id = pl.id
  WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  GROUP BY ug.user_id, ug.game_title_id
) max_scores ON p.id = max_scores.user_id
WHERE p.id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
GROUP BY p.username, p.id;
