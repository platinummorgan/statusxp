-- Check what Gordon's ACTUAL gamerscore should be (deduplicated by game name)
SELECT 
  p.username,
  p.id as user_id,
  SUM(max_scores.max_gs) as correct_gamerscore
FROM profiles p
INNER JOIN (
  SELECT 
    ug.user_id,
    gt.name as game_name,
    MAX(ug.xbox_current_gamerscore) as max_gs
  FROM user_games ug
  INNER JOIN game_titles gt ON ug.game_title_id = gt.id
  INNER JOIN platforms pl ON ug.platform_id = pl.id
  WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  GROUP BY ug.user_id, gt.name
) max_scores ON p.id = max_scores.user_id
WHERE p.id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
GROUP BY p.username, p.id;
