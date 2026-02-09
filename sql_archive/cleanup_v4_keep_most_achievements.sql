-- ============================================================================
-- CLEANUP V4: Keep platform with MOST achievements for each game_id
-- ============================================================================
-- Strategy: For duplicates, keep the platform where user has the most achievements
-- This ensures we keep the REAL platform, not fake entries
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Identify which platform to keep (one with most achievements)
-- ============================================================================
CREATE TEMP TABLE games_to_keep AS
SELECT DISTINCT ON (platform_game_id)
  platform_id,
  platform_game_id,
  total_achievements
FROM (
  SELECT 
    g.platform_id,
    g.platform_game_id,
    COALESCE(SUM(CASE WHEN ua.platform_achievement_id IS NOT NULL THEN 1 ELSE 0 END), 0) as total_achievements
  FROM games g
  LEFT JOIN user_achievements ua ON g.platform_id = ua.platform_id 
    AND g.platform_game_id = ua.platform_game_id
  WHERE g.platform_id IN (1, 2, 4, 5, 9, 10, 11, 12)
  GROUP BY g.platform_id, g.platform_game_id
) sub
ORDER BY 
  platform_game_id,
  total_achievements DESC, -- Keep platform with MOST achievements
  platform_id ASC; -- Tiebreaker: prefer lower platform_id

-- ============================================================================
-- STEP 2: Delete user_achievements for games NOT in keep list
-- ============================================================================
DELETE FROM user_achievements
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- STEP 3: Delete user_progress for games NOT in keep list
-- ============================================================================
DELETE FROM user_progress
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- STEP 4: Delete achievements definitions
-- ============================================================================
DELETE FROM achievements
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- STEP 5: Delete game entries
-- ============================================================================
DELETE FROM games
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 
  'Cleanup Complete' as status,
  (SELECT COUNT(*) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as remaining_games,
  (SELECT COUNT(DISTINCT platform_game_id) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as unique_games;

-- Run COMMIT; to save or ROLLBACK; to undo
