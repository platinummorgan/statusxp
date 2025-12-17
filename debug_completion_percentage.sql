-- Check why PS4/PS5 games show 100% completion

-- 1. Check a specific game: Persona 5 Royal
SELECT 
  'Total achievements in DB' as metric,
  COUNT(*) as count
FROM achievements
WHERE game_title_id = (SELECT id FROM game_titles WHERE name = 'Persona 5 Royal')
  AND platform = 'psn'

UNION ALL

SELECT 
  'User earned achievements' as metric,
  COUNT(*) as count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.game_title_id = (SELECT id FROM game_titles WHERE name = 'Persona 5 Royal')
  AND a.platform = 'psn'
  AND ua.user_id = (SELECT id FROM profiles LIMIT 1)

UNION ALL

SELECT 
  'user_games.total_trophies' as metric,
  ug.total_trophies as count
FROM user_games ug
WHERE ug.game_title_id = (SELECT id FROM game_titles WHERE name = 'Persona 5 Royal')
  AND ug.platform_id = (SELECT id FROM platforms WHERE code = 'PS5')
  AND ug.user_id = (SELECT id FROM profiles LIMIT 1);

-- 2. Check Sekiro on PS4 (should have more than 34 achievements total)
SELECT 
  'Total Sekiro achievements in DB' as metric,
  COUNT(*) as count
FROM achievements
WHERE game_title_id = (SELECT id FROM game_titles WHERE name LIKE 'Sekiro%')
  AND platform = 'psn'

UNION ALL

SELECT 
  'User earned Sekiro achievements' as metric,
  COUNT(*) as count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.game_title_id = (SELECT id FROM game_titles WHERE name LIKE 'Sekiro%')
  AND a.platform = 'psn'
  AND ua.user_id = (SELECT id FROM profiles LIMIT 1);

-- 3. Sample of unearned PS4/PS5 achievements from any game
SELECT 
  gt.name as game,
  a.name as achievement,
  a.rarity_global
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'psn'
  AND a.game_title_id IN (
    SELECT DISTINCT game_title_id 
    FROM user_games 
    WHERE user_id = (SELECT id FROM profiles LIMIT 1)
      AND platform_id IN (SELECT id FROM platforms WHERE code IN ('PS4', 'PS5'))
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua 
    WHERE ua.achievement_id = a.id 
      AND ua.user_id = (SELECT id FROM profiles LIMIT 1)
  )
LIMIT 20;
