-- Check unique game titles vs total user_games
SELECT 
  COUNT(DISTINCT ug.game_title_id) as unique_game_titles,
  COUNT(*) as total_user_game_entries,
  COUNT(*) - COUNT(DISTINCT ug.game_title_id) as duplicate_titles
FROM user_games ug
WHERE ug.user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan');

-- Show games with multiple platform entries
SELECT 
  gt.name,
  COUNT(*) as platform_count,
  STRING_AGG(pl.code, ', ') as platforms
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
WHERE ug.user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan')
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY platform_count DESC
LIMIT 20;
