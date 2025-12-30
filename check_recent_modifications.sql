-- Check if Dex-Morgan's user_games have been modified recently (during gordonops sync)
SELECT 
  COUNT(*) as recently_modified_games,
  MAX(updated_at) as last_update
FROM user_games
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan')
  AND updated_at > NOW() - INTERVAL '5 minutes';

-- Check if any games got statusxp_effective set to 0 or NULL recently
SELECT 
  gt.name,
  ug.statusxp_effective,
  ug.updated_at
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan')
  AND ug.updated_at > NOW() - INTERVAL '5 minutes'
ORDER BY ug.updated_at DESC
LIMIT 20;
