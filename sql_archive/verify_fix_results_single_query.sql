-- ============================================
-- SINGLE QUERY: Shows all fix results at once
-- Run this in your CURRENT transaction (same tab)
-- ============================================

WITH 
-- Count deleted duplicates
deleted_stats AS (
  SELECT COUNT(*) as deleted_count
  FROM duplicates_to_delete
),
-- Count updated records
updated_stats AS (
  SELECT 
    COUNT(*) as updated_count,
    COUNT(*) FILTER (WHERE user_game_id IN (
      SELECT ug.id FROM user_games ug
      WHERE ug.updated_at >= NOW() - INTERVAL '5 minutes'
    )) as confirmed_updates
  FROM records_to_update
),
-- Check remaining mismatches (SHOULD BE 0)
remaining_mismatches AS (
  SELECT COUNT(DISTINCT ug.id) as mismatch_count
  FROM (
    SELECT 
      ua.user_id,
      a.game_title_id,
      a.platform
    FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    GROUP BY ua.user_id, a.game_title_id, a.platform
  ) ap
  JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
  LEFT JOIN platforms p ON p.id = ug.platform_id
  WHERE (
    (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
    (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
    (ap.platform = 'steam' AND p.code != 'Steam')
  )
)
-- Combine everything into one result
SELECT 
  'FIX RESULTS SUMMARY' as report,
  ds.deleted_count as duplicates_deleted,
  us.updated_count as records_updated,
  us.confirmed_updates as confirmed_by_updated_at,
  rm.mismatch_count as remaining_mismatches,
  CASE 
    WHEN rm.mismatch_count = 0 THEN '✓ SUCCESS - All 153 records fixed!'
    ELSE '✗ FAILED - Still have ' || rm.mismatch_count || ' mismatches'
  END as verdict,
  CASE 
    WHEN rm.mismatch_count = 0 THEN 'Type: COMMIT;'
    ELSE 'Type: ROLLBACK; and investigate'
  END as next_step
FROM deleted_stats ds, updated_stats us, remaining_mismatches rm;
