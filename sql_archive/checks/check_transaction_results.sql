-- ============================================
-- Check results of the transaction that's still open
-- Run these queries in your CURRENT SQL Editor session
-- (same tab where the transaction is open)
-- ============================================

-- Query 1: How many duplicates were deleted?
SELECT 
  'DELETED DUPLICATES' as status,
  COUNT(*) as deleted_count
FROM duplicates_to_delete;

-- Query 2: How many records were updated?
SELECT 
  'UPDATED RECORDS' as status,
  COUNT(*) as updated_count
FROM records_to_update rtu
WHERE EXISTS (
  SELECT 1 FROM user_games ug
  WHERE ug.id = rtu.user_game_id
    AND ug.updated_at >= NOW() - INTERVAL '5 minutes'
);

-- Query 3: How many mismatches remain? (SHOULD BE 0)
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
  'VERIFICATION: Remaining mismatches' as status,
  COUNT(DISTINCT ug.id) as remaining_mismatches
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
);
