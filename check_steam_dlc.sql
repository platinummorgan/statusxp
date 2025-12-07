-- Check Steam DLC detection
SELECT 
  gt.name as game_name,
  a.name as achievement_name,
  a.is_dlc,
  a.dlc_name
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'steam' AND a.is_dlc = true
LIMIT 20;

-- Count Steam DLC vs base game
SELECT 
  is_dlc,
  COUNT(*) as count
FROM achievements
WHERE platform = 'steam'
GROUP BY is_dlc;
