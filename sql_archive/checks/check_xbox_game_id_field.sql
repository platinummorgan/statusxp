-- Check user_games table structure for Xbox game ID fields
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_games'
ORDER BY ordinal_position;

-- Check if there's an xbox-specific game identifier
SELECT 
  ug.game_title_id,
  gt.name,
  gt.xbox_title_id,
  gt.xbox_product_id,
  ug.xbox_current_gamerscore
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 0
ORDER BY gt.name
LIMIT 20;
