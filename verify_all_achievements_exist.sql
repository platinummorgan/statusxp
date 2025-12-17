-- Check if more achievements exist in DB for your games

-- 1. Compare total achievements in DB vs user_games.total_trophies
SELECT 
  gt.name as game,
  p.code as platform,
  ug.total_trophies as "user_games says",
  COUNT(a.id) as "actually in DB",
  ug.earned_trophies as "you earned"
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
LEFT JOIN achievements a ON a.game_title_id = ug.game_title_id 
  AND ((a.platform = 'psn' AND p.code IN ('PS3', 'PS4', 'PS5', 'PSVITA'))
    OR (a.platform = 'xbox' AND p.code LIKE '%XBOX%')
    OR (a.platform = 'steam' AND p.code = 'Steam'))
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY gt.name, p.code, ug.total_trophies, ug.earned_trophies
HAVING COUNT(a.id) != ug.total_trophies
ORDER BY "actually in DB" DESC;

-- 2. Check any random PS4 game to see if uneraned achievements exist
SELECT 
  a.name,
  a.psn_trophy_type,
  EXISTS(
    SELECT 1 FROM user_achievements ua 
    WHERE ua.achievement_id = a.id 
      AND ua.user_id = (SELECT id FROM profiles LIMIT 1)
  ) as "you earned it"
FROM achievements a
WHERE a.game_title_id = (SELECT id FROM game_titles WHERE name = 'Persona 5 Royal')
  AND a.platform = 'psn'
ORDER BY a.id
LIMIT 10;
