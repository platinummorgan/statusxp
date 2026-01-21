-- Check [PROTOTYPE] achievements in the system

-- First, find the game in the games table
SELECT 
  g.platform_id,
  p.name as platform_name,
  g.platform_game_id,
  g.name,
  g.cover_url
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.name ILIKE '%PROTOTYPE%'
ORDER BY g.platform_id;

-- Check if there are achievements for this game
SELECT 
  a.platform_id,
  p.name as platform_name,
  a.platform_game_id,
  COUNT(*) as achievement_count
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
WHERE a.platform_game_id IN (
  SELECT DISTINCT platform_game_id 
  FROM games 
  WHERE name ILIKE '%PROTOTYPE%'
)
GROUP BY a.platform_id, p.name, a.platform_game_id
ORDER BY a.platform_id;

-- Check specific achievements for platform_id=11, game_id='1096157262'
SELECT 
  platform_achievement_id,
  name,
  description,
  rarity_global,
  base_status_xp
FROM achievements
WHERE platform_id = 11 
  AND platform_game_id = '1096157262'
LIMIT 20;

-- Also check for any variations of the game ID
SELECT DISTINCT 
  g.platform_id,
  p.name as platform_name,
  g.platform_game_id,
  g.name,
  (SELECT COUNT(*) 
   FROM achievements a 
   WHERE a.platform_id = g.platform_id 
     AND a.platform_game_id = g.platform_game_id) as achievement_count
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.name ILIKE '%PROTOTYPE%'
ORDER BY g.platform_id;
