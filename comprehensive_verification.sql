-- Comprehensive data verification tests

-- TEST 1: Count all games you have ANY trophies for vs games in user_games
SELECT 
  'Games with earned trophies in DB' as metric,
  COUNT(DISTINCT gt.id) as count
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = (SELECT id FROM profiles LIMIT 1)
  AND a.platform = 'psn'

UNION ALL

SELECT 
  'Games in your user_games table' as metric,
  COUNT(DISTINCT game_title_id) as count
FROM user_games
WHERE user_id = (SELECT id FROM profiles LIMIT 1)
  AND platform_id IN (SELECT id FROM platforms WHERE code IN ('PS3', 'PS4', 'PS5', 'PSVITA'));

-- TEST 2: List ALL PSN games you have trophies for (not just the 10 in user_games)
SELECT 
  gt.name,
  COUNT(ua.id) as trophies_earned,
  MIN(ua.earned_at) as first_trophy,
  MAX(ua.earned_at) as last_trophy,
  EXISTS(
    SELECT 1 FROM user_games ug 
    WHERE ug.game_title_id = gt.id 
      AND ug.user_id = (SELECT id FROM profiles LIMIT 1)
  ) as "in user_games?"
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = (SELECT id FROM profiles LIMIT 1)
  AND a.platform = 'psn'
GROUP BY gt.name
ORDER BY trophies_earned DESC;

-- TEST 3: Find games with partial completion
SELECT 
  gt.name,
  COUNT(DISTINCT a.id) as total_achievements,
  COUNT(DISTINCT ua.id) as earned_achievements,
  ROUND((COUNT(DISTINCT ua.id)::numeric / NULLIF(COUNT(DISTINCT a.id), 0) * 100), 2) as actual_completion
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id 
  AND ua.user_id = (SELECT id FROM profiles LIMIT 1)
WHERE a.platform = 'psn'
  AND gt.id IN (
    SELECT DISTINCT a2.game_title_id 
    FROM achievements a2
    JOIN user_achievements ua2 ON ua2.achievement_id = a2.id
    WHERE ua2.user_id = (SELECT id FROM profiles LIMIT 1)
      AND a2.platform = 'psn'
  )
GROUP BY gt.name
HAVING COUNT(DISTINCT ua.id) > 0 
  AND COUNT(DISTINCT ua.id) < COUNT(DISTINCT a.id)
ORDER BY actual_completion DESC;

-- TEST 4: Sample of PSN achievements you HAVEN'T earned
SELECT 
  gt.name as game,
  a.name as achievement,
  a.psn_trophy_type,
  a.rarity_global
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'psn'
  AND a.game_title_id IN (
    -- Games where you have at least 1 trophy
    SELECT DISTINCT a2.game_title_id 
    FROM achievements a2
    JOIN user_achievements ua2 ON ua2.achievement_id = a2.id
    WHERE ua2.user_id = (SELECT id FROM profiles LIMIT 1)
      AND a2.platform = 'psn'
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    WHERE ua.achievement_id = a.id
      AND ua.user_id = (SELECT id FROM profiles LIMIT 1)
  )
ORDER BY gt.name, a.id
LIMIT 20;
