-- Check for potential duplicate games across platforms (ENTIRE DATABASE)
-- Games with same name on multiple platforms (legitimate cross-platform)
SELECT 
  g.name,
  COUNT(DISTINCT g.platform_id) as platform_count,
  STRING_AGG(DISTINCT p.name || ' (ID: ' || g.platform_id || ')', ', ' ORDER BY p.name || ' (ID: ' || g.platform_id || ')') as platforms,
  STRING_AGG(DISTINCT g.platform_game_id, ', ') as game_ids
FROM games g
JOIN platforms p ON p.id = g.platform_id
GROUP BY g.name
HAVING COUNT(DISTINCT g.platform_id) > 1
ORDER BY platform_count DESC, g.name;

-- Check for users with progress on cross-platform games
SELECT 
  up.user_id,
  g.name,
  up.platform_id,
  p.name as platform_name,
  up.achievements_earned,
  up.total_achievements
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
JOIN platforms p ON p.id = up.platform_id
WHERE g.name IN (
    SELECT name 
    FROM games 
    GROUP BY name 
    HAVING COUNT(DISTINCT platform_id) > 1
  )
ORDER BY g.name, up.user_id, up.platform_id
LIMIT 50;

-- Summary counts
SELECT 
  'Total unique game names' as metric,
  COUNT(DISTINCT name) as count
FROM games
UNION ALL
SELECT 
  'Total game entries (with platform_id)',
  COUNT(*)
FROM games
UNION ALL
SELECT 
  'Cross-platform games (same name, different platforms)',
  COUNT(DISTINCT name)
FROM games
WHERE name IN (
    SELECT name 
    FROM games 
    GROUP BY name 
    HAVING COUNT(DISTINCT platform_id) > 1
  );
