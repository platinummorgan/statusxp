-- Check Gordon's Xbox games for duplicates
SELECT 
  gt.name,
  COUNT(*) as duplicate_count,
  STRING_AGG(DISTINCT ug.game_title_id::text, ', ') as game_title_ids,
  STRING_AGG(DISTINCT ug.xbox_current_gamerscore::text, ', ') as gamerscores,
  MAX(ug.xbox_current_gamerscore) as max_score,
  SUM(ug.xbox_current_gamerscore) as sum_score
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore IS NOT NULL
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY SUM(ug.xbox_current_gamerscore) - MAX(ug.xbox_current_gamerscore) DESC
LIMIT 20;

-- Also get total counts
SELECT 
  COUNT(DISTINCT gt.name) as unique_game_names,
  COUNT(DISTINCT ug.game_title_id) as total_game_entries,
  SUM(ug.xbox_current_gamerscore) as total_with_dupes,
  (SELECT SUM(max_gs) FROM (
    SELECT MAX(ug2.xbox_current_gamerscore) as max_gs
    FROM user_games ug2
    JOIN game_titles gt2 ON ug2.game_title_id = gt2.id
    JOIN platforms pl2 ON ug2.platform_id = pl2.id
    JOIN profiles p2 ON p2.id = ug2.user_id
    WHERE p2.xbox_gamertag = 'XxlmThumperxX'
      AND pl2.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    GROUP BY gt2.name
  ) deduped) as deduplicated_total
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore IS NOT NULL;
