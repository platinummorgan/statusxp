-- Check if there's an xbox-specific game identifier in game_titles
SELECT 
  ug.game_title_id,
  gt.name,
  gt.xbox_title_id,
  gt.xbox_product_id,
  ug.xbox_current_gamerscore,
  pl.code as platform
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 0
ORDER BY gt.name
LIMIT 30;
