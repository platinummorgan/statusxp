-- Check if duplicate game names have different xbox_title_ids
SELECT 
  gt.name,
  COUNT(DISTINCT ug.game_title_id) as db_entries,
  COUNT(DISTINCT gt.xbox_title_id) as unique_xbox_ids,
  STRING_AGG(DISTINCT gt.xbox_title_id, ', ') as xbox_title_ids,
  STRING_AGG(DISTINCT ug.xbox_current_gamerscore::text, ', ') as gamerscores
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 0
GROUP BY gt.name
HAVING COUNT(DISTINCT ug.game_title_id) > 1
ORDER BY COUNT(DISTINCT gt.xbox_title_id) DESC
LIMIT 20;

-- Check total games and gamerscore grouping by xbox_title_id instead of name
SELECT 
  COUNT(DISTINCT xbox_title_id) as unique_xbox_titles,
  SUM(max_gs) as total_gamerscore
FROM (
  SELECT 
    gt.xbox_title_id,
    MAX(ug.xbox_current_gamerscore) as max_gs
  FROM user_games ug
  JOIN game_titles gt ON ug.game_title_id = gt.id
  JOIN platforms pl ON ug.platform_id = pl.id
  JOIN profiles p ON p.id = ug.user_id
  WHERE p.xbox_gamertag = 'XxlmThumperxX'
    AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    AND gt.xbox_title_id IS NOT NULL
  GROUP BY gt.xbox_title_id
) deduped;
