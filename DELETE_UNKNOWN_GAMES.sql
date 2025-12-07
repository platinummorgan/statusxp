-- ============================================================================
-- DELETE OLD UNKNOWN GAMES
-- This removes the duplicate "unknown" platform game records
-- The sync has already created new records with correct platform_id
-- ============================================================================

-- Delete user_games with NULL platform_id (these are the old broken records)
DELETE FROM user_games
WHERE platform_id IS NULL;

-- Verify - should return 0
SELECT COUNT(*) as remaining_unknown_games
FROM user_games
WHERE platform_id IS NULL;

-- Check final counts by platform
SELECT 
  p.code as platform,
  COUNT(*) as game_count
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
GROUP BY p.code
ORDER BY game_count DESC;
