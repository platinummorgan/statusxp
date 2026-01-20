-- Check how many games don't have xbox_title_id
SELECT 
  COUNT(*) as games_without_xbox_id,
  SUM(ug.xbox_current_gamerscore) as missing_gamerscore
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 0
  AND gt.xbox_title_id IS NULL;

-- Show examples of games without xbox_title_id
SELECT 
  gt.name,
  ug.xbox_current_gamerscore
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 0
  AND gt.xbox_title_id IS NULL
LIMIT 20;
