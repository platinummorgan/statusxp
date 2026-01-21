-- ============================================================================
-- Audit: Find games incorrectly duplicated across platform generations
-- ============================================================================
-- This checks for games that exist on multiple platforms with the SAME game ID
-- which indicates backwards compatibility issues (PS4 on PS5, Xbox 360 on Xbox One, etc.)

-- PART 1: Find PS4/PS5 duplicates (same game_id on both platforms)
SELECT 
  'PS4/PS5 Duplicate' as issue_type,
  g1.platform_game_id,
  g1.name,
  g1.platform_id as ps5_platform_id,
  g2.platform_id as ps4_platform_id,
  (SELECT COUNT(*) FROM achievements WHERE platform_id = 1 AND platform_game_id = g1.platform_game_id) as ps5_achievements,
  (SELECT COUNT(*) FROM achievements WHERE platform_id = 2 AND platform_game_id = g1.platform_game_id) as ps4_achievements,
  CASE 
    WHEN (SELECT COUNT(*) FROM achievements WHERE platform_id = 1 AND platform_game_id = g1.platform_game_id) > 0 
    THEN 'Achievements on PS5'
    ELSE 'No achievements on PS5'
  END as status
FROM games g1
JOIN games g2 ON g1.platform_game_id = g2.platform_game_id 
  AND g1.name = g2.name
WHERE g1.platform_id = 1  -- PS5
  AND g2.platform_id = 2  -- PS4
ORDER BY ps5_achievements DESC;

-- PART 2: Find Xbox 360/Xbox One/Xbox Series X duplicates
SELECT 
  'Xbox Multi-Gen Duplicate' as issue_type,
  g1.platform_game_id,
  g1.name,
  STRING_AGG(DISTINCT p.name, ', ' ORDER BY p.name) as platforms_found,
  (SELECT COUNT(*) FROM achievements WHERE platform_id = 10 AND platform_game_id = g1.platform_game_id) as xbox360_achievements,
  (SELECT COUNT(*) FROM achievements WHERE platform_id = 11 AND platform_game_id = g1.platform_game_id) as xboxone_achievements,
  (SELECT COUNT(*) FROM achievements WHERE platform_id = 12 AND platform_game_id = g1.platform_game_id) as xboxseriesx_achievements
FROM games g1
JOIN platforms p ON p.id = g1.platform_id
WHERE g1.platform_id IN (10, 11, 12)  -- Xbox 360, One, Series X
GROUP BY g1.platform_game_id, g1.name
HAVING COUNT(DISTINCT g1.platform_id) > 1  -- Game exists on multiple Xbox platforms
ORDER BY g1.name;

-- PART 3: Summary counts
SELECT 
  'PS4/PS5' as platform_family,
  COUNT(*) as games_with_duplicates
FROM (
  SELECT DISTINCT g1.platform_game_id
  FROM games g1
  JOIN games g2 ON g1.platform_game_id = g2.platform_game_id
  WHERE g1.platform_id = 1 AND g2.platform_id = 2
) sub
UNION ALL
SELECT 
  'Xbox (360/One/Series)' as platform_family,
  COUNT(*) as games_with_duplicates
FROM (
  SELECT platform_game_id
  FROM games
  WHERE platform_id IN (10, 11, 12)
  GROUP BY platform_game_id, name
  HAVING COUNT(DISTINCT platform_id) > 1
) sub;

-- PART 4: Find games where achievements are on wrong platform
-- (e.g., PS5 has achievements but PS4 entry exists = should be PS4)
SELECT 
  'Achievements on wrong platform' as issue_type,
  g.platform_game_id,
  g.name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM games WHERE platform_id = 2 AND platform_game_id = g.platform_game_id)
    THEN 'Should be PS4'
    ELSE 'Unknown'
  END as correct_platform,
  (SELECT COUNT(*) FROM achievements WHERE platform_id = 1 AND platform_game_id = g.platform_game_id) as ps5_achievements,
  (SELECT COUNT(*) FROM achievements WHERE platform_id = 2 AND platform_game_id = g.platform_game_id) as ps4_achievements
FROM games g
WHERE g.platform_id = 1  -- PS5
  AND EXISTS (
    SELECT 1 FROM achievements 
    WHERE platform_id = 1 
      AND platform_game_id = g.platform_game_id
  )
  AND EXISTS (
    SELECT 1 FROM games 
    WHERE platform_id = 2  -- PS4 version exists
      AND platform_game_id = g.platform_game_id
  )
ORDER BY ps5_achievements DESC;

-- PART 5: Check for PSVita/PS3 cross-gen issues
SELECT 
  'PS3/Vita Duplicate' as issue_type,
  g1.platform_game_id,
  g1.name,
  STRING_AGG(DISTINCT p.name, ', ' ORDER BY p.name) as platforms_found,
  (SELECT COUNT(*) FROM achievements a WHERE a.platform_id = g1.platform_id AND a.platform_game_id = g1.platform_game_id) as achievement_count
FROM games g1
JOIN platforms p ON p.id = g1.platform_id
WHERE g1.platform_id IN (3, 4)  -- PS3, PSVita
GROUP BY g1.platform_game_id, g1.name
HAVING COUNT(DISTINCT g1.platform_id) > 1
ORDER BY achievement_count DESC;
