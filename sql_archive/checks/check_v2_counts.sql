-- Check migration counts
SELECT 
  'games_v2' as table_name,
  COUNT(*) as total_entries,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_games,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_games
FROM games_v2

UNION ALL

SELECT 
  'user_progress_v2' as table_name,
  COUNT(*) as total_entries,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_entries,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_entries
FROM user_progress_v2

UNION ALL

SELECT 
  'user_achievements_v2' as table_name,
  COUNT(*) as total_entries,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_earned,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_earned
FROM user_achievements_v2;
