-- Check for same-platform Xbox duplication (Xbox 360 vs Xbox One)
-- Shows if users have the same xbox_title_id counted multiple times
SELECT 
  p.display_name,
  gt.xbox_title_id,
  gt.name,
  COUNT(*) as duplicate_count,
  STRING_AGG(DISTINCT pl.code, ', ') as platforms,
  SUM(ug.xbox_current_gamerscore) as total_gamerscore
FROM profiles p
JOIN user_games ug ON ug.user_id = p.id
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms pl ON pl.id = ug.platform_id
WHERE p.display_name IN ('Otaku EVO IX', 'XxlmThumperxX', 'TeaTonicDark')
  AND gt.xbox_title_id IS NOT NULL
  AND ug.xbox_current_gamerscore > 0
GROUP BY p.display_name, gt.xbox_title_id, gt.name
HAVING COUNT(*) > 1  -- Only show duplicates
ORDER BY p.display_name, total_gamerscore DESC;

-- Also check: are there multiple game_title_id entries with the SAME xbox_title_id?
-- This would indicate game_titles table duplicates
SELECT 
  gt.xbox_title_id,
  gt.name,
  COUNT(DISTINCT gt.id) as different_game_title_ids,
  STRING_AGG(DISTINCT gt.id::text, ', ') as game_title_ids
FROM game_titles gt
WHERE gt.xbox_title_id IS NOT NULL
GROUP BY gt.xbox_title_id, gt.name
HAVING COUNT(DISTINCT gt.id) > 1
ORDER BY different_game_title_ids DESC
LIMIT 20;
