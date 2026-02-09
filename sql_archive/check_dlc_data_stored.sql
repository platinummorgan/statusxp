-- Check if PSN sync actually stored DLC names
-- Run this to see what happened

-- 1. Check any PSN achievements with DLC data
SELECT 
  g.name as game_name,
  COUNT(*) as total_achievements,
  COUNT(*) FILTER (WHERE a.metadata->>'dlc_name' IS NOT NULL) as with_dlc_name,
  COUNT(*) FILTER (WHERE a.metadata->>'is_dlc' = 'true') as marked_as_dlc,
  ARRAY_AGG(DISTINCT a.metadata->>'dlc_name') FILTER (WHERE a.metadata->>'dlc_name' IS NOT NULL) as dlc_names
FROM achievements a
JOIN games g ON a.platform_game_id = g.platform_game_id AND a.platform_id = g.platform_id
WHERE a.platform_id IN (1, 2)
GROUP BY g.name
HAVING COUNT(*) FILTER (WHERE a.metadata->>'dlc_name' IS NOT NULL) > 0
ORDER BY g.name;

-- 2. If nothing above, check a specific game (replace with your game name)
SELECT 
  a.name as achievement_name,
  a.metadata->>'trophy_group_id' as trophy_group_id,
  a.metadata->>'is_dlc' as is_dlc,
  a.metadata->>'dlc_name' as dlc_name,
  a.metadata
FROM achievements a
JOIN games g ON a.platform_game_id = g.platform_game_id AND a.platform_id = g.platform_id
WHERE g.name ILIKE '%resident evil%'  -- Change this to your game
  AND a.platform_id IN (1, 2)
ORDER BY 
  CASE WHEN a.metadata->>'trophy_group_id' IS NULL THEN '0' ELSE a.metadata->>'trophy_group_id' END,
  a.name
LIMIT 20;

-- 3. Check if games have hasTrophyGroups flag
SELECT 
  name,
  platform_id,
  metadata->>'has_trophy_groups' as has_trophy_groups,
  metadata->>'np_communication_id' as np_comm_id
FROM games
WHERE platform_id IN (1, 2)
  AND name ILIKE '%resident evil%'  -- Change this to your game
ORDER BY name;
