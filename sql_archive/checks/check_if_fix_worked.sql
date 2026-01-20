-- ============================================
-- Check if the fix was actually applied
-- This queries the real database, not temp tables
-- ============================================

-- Check 1: Do the 153 mismatches still exist?
WITH achievement_platforms AS (
  SELECT 
    ua.user_id,
    a.game_title_id,
    a.platform,
    COUNT(*) as achievement_count
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  GROUP BY ua.user_id, a.game_title_id, a.platform
)
SELECT 
  'CURRENT DATABASE STATE' as check_type,
  COUNT(DISTINCT ug.id) as current_mismatches,
  CASE 
    WHEN COUNT(DISTINCT ug.id) = 0 THEN '✓ FIX WORKED! All mismatches resolved!'
    WHEN COUNT(DISTINCT ug.id) = 153 THEN '✗ FIX FAILED - Still have all 153 mismatches'
    ELSE '⚠ PARTIAL - Some fixed, ' || COUNT(DISTINCT ug.id) || ' remain'
  END as status
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
);

-- Check 2: Were any records updated in the last 10 minutes?
SELECT 
  'RECENT UPDATES CHECK' as check_type,
  COUNT(*) as records_updated_recently,
  MAX(updated_at) as most_recent_update
FROM user_games
WHERE updated_at >= NOW() - INTERVAL '10 minutes';
