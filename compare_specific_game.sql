-- Detailed achievement comparison for a specific game
-- INSTRUCTIONS: Replace 'YOUR_GAME_NAME' below with an actual game you have on both platforms
-- Example: 'Resident Evil 7', 'Fallout 4', 'The Witcher 3', etc.

WITH game_to_check AS (
  SELECT 'Resident Evil 7' as search_name  -- ⚠️ CHANGE THIS
),

psn_game AS (
  SELECT g.platform_game_id, g.platform_id, g.name
  FROM games g, game_to_check gtc
  WHERE g.name ILIKE '%' || gtc.search_name || '%'
    AND g.platform_id IN (1, 2)
  LIMIT 1
),

xbox_game AS (
  SELECT g.platform_game_id, g.platform_id, g.name
  FROM games g, game_to_check gtc
  WHERE g.name ILIKE '%' || gtc.search_name || '%'
    AND g.platform_id IN (10, 11, 12)
  LIMIT 1
)

SELECT 
  '=== PSN ACHIEVEMENTS (with DLC groups) ===' as section,
  NULL as dlc_group,
  NULL as achievement_name,
  NULL as description

UNION ALL

SELECT 
  '---' as section,
  COALESCE(a.metadata->>'dlc_name', 'Base Game') as dlc_group,
  a.name as achievement_name,
  LEFT(a.description, 60) as description
FROM achievements a
JOIN psn_game pg ON a.platform_game_id = pg.platform_game_id 
  AND a.platform_id = pg.platform_id
ORDER BY 
  CASE WHEN a.metadata->>'trophy_group_id' IS NULL THEN '0' ELSE a.metadata->>'trophy_group_id' END,
  a.name

UNION ALL

SELECT 
  '',
  '',
  '',
  ''

UNION ALL

SELECT 
  '=== XBOX ACHIEVEMENTS (no DLC separation) ===' as section,
  NULL,
  NULL,
  NULL

UNION ALL

SELECT 
  '---' as section,
  'Base Game' as dlc_group,
  a.name as achievement_name,
  LEFT(a.description, 60) as description
FROM achievements a
JOIN xbox_game xg ON a.platform_game_id = xg.platform_game_id 
  AND a.platform_id = xg.platform_id
ORDER BY a.name;
