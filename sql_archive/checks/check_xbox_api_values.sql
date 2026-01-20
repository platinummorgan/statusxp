-- Check if Gordon's 487 games and 327,990 gamerscore matches counting by game_title_id
SELECT 
  COUNT(DISTINCT ug.game_title_id) as total_games_by_id,
  SUM(ug.xbox_current_gamerscore) as total_gamerscore_no_dedup
FROM user_games ug
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore IS NOT NULL
  AND ug.xbox_current_gamerscore > 0;

-- Also check what Xbox API actually reports (if stored in profiles)
SELECT 
  xbox_gamerscore,
  xbox_games_count
FROM profiles
WHERE xbox_gamertag = 'XxlmThumperxX';
