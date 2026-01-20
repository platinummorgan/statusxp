-- Check if the 66 games without xbox_title_id also have duplicates by name
SELECT 
  gt.name,
  COUNT(*) as duplicate_count,
  STRING_AGG(DISTINCT ug.game_title_id::text, ', ') as game_title_ids,
  MAX(ug.xbox_current_gamerscore) as max_score,
  SUM(ug.xbox_current_gamerscore) as sum_score
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 0
  AND gt.xbox_title_id IS NULL
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY SUM(ug.xbox_current_gamerscore) - MAX(ug.xbox_current_gamerscore) DESC;

-- Calculate what we'd get if we deduplicate the NULL games by name
SELECT 
  COUNT(DISTINCT name) as unique_names_in_null_games,
  SUM(max_gs) as gamerscore_if_deduped_by_name
FROM (
  SELECT 
    gt.name,
    MAX(ug.xbox_current_gamerscore) as max_gs
  FROM user_games ug
  JOIN game_titles gt ON ug.game_title_id = gt.id
  JOIN platforms pl ON ug.platform_id = pl.id
  JOIN profiles p ON p.id = ug.user_id
  WHERE p.xbox_gamertag = 'XxlmThumperxX'
    AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    AND ug.xbox_current_gamerscore > 0
    AND gt.xbox_title_id IS NULL
  GROUP BY gt.name
) deduped;
