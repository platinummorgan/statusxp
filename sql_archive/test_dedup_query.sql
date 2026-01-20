-- Test the deduplication logic for Gordon
SELECT 
  user_id,
  SUM(max_gamerscore) as total_gamerscore,
  COUNT(*) as total_games
FROM (
  SELECT 
    ug.user_id,
    COALESCE(gt.xbox_title_id, 'NAME:' || gt.name) as unique_game_key,
    MAX(ug.xbox_current_gamerscore) as max_gamerscore
  FROM user_games ug
  JOIN game_titles gt ON ug.game_title_id = gt.id
  JOIN platforms pl ON ug.platform_id = pl.id
  JOIN profiles p ON p.id = ug.user_id
  WHERE p.xbox_gamertag = 'XxlmThumperxX'
    AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    AND ug.xbox_current_gamerscore IS NOT NULL
    AND ug.xbox_current_gamerscore > 0
  GROUP BY ug.user_id, COALESCE(gt.xbox_title_id, 'NAME:' || gt.name)
) deduplicated_games
GROUP BY user_id;
