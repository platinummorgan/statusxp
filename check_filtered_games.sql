-- Check what the leaderboard ACTUALLY sees for Dex-Morgan
SELECT 
  COUNT(DISTINCT ug.game_title_id) as unique_games_in_query,
  COUNT(*) as total_entries_in_query,
  SUM(ug.statusxp_effective) as statusxp_from_query
FROM user_games ug
INNER JOIN profiles p ON p.id = ug.user_id
WHERE p.username = 'Dex-Morgan';

-- Check if there's a filter on statusxp_effective > 0
SELECT 
  COUNT(*) as games_with_zero_statusxp
FROM user_games ug
WHERE ug.user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan')
  AND (ug.statusxp_effective IS NULL OR ug.statusxp_effective = 0);

-- Check games by statusxp value
SELECT 
  CASE 
    WHEN statusxp_effective IS NULL THEN 'NULL'
    WHEN statusxp_effective = 0 THEN 'ZERO'
    WHEN statusxp_effective > 0 THEN 'HAS_VALUE'
  END as statusxp_category,
  COUNT(*) as game_count
FROM user_games
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan')
GROUP BY 
  CASE 
    WHEN statusxp_effective IS NULL THEN 'NULL'
    WHEN statusxp_effective = 0 THEN 'ZERO'
    WHEN statusxp_effective > 0 THEN 'HAS_VALUE'
  END;
