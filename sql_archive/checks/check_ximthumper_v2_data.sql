-- Check X_imThumper_X's data in v2 schema

-- Check user_progress_v2 for X_imThumper_X
SELECT 
  COUNT(*) as games_in_v2,
  SUM(current_score) as total_gs_v2
FROM user_progress_v2
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';

-- Check which games have xbox_title_id vs which don't
SELECT 
  'Has xbox_title_id' as category,
  COUNT(*) as game_count,
  SUM(ug.xbox_current_gamerscore) as total_gs
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND gt.xbox_title_id IS NOT NULL
  AND ug.xbox_current_gamerscore IS NOT NULL

UNION ALL

SELECT 
  'Missing xbox_title_id' as category,
  COUNT(*) as game_count,
  SUM(ug.xbox_current_gamerscore) as total_gs
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND gt.xbox_title_id IS NULL;

-- Sample of games missing xbox_title_id
SELECT 
  gt.name,
  p.code as platform,
  ug.xbox_current_gamerscore
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND gt.xbox_title_id IS NULL
ORDER BY ug.xbox_current_gamerscore DESC
LIMIT 20;
