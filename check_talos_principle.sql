-- Check The Talos Principle 2

-- 1. Does the game exist in game_titles?
SELECT 
  id,
  name,
  cover_url
FROM game_titles
WHERE name ILIKE '%talos%';

-- 2. Are there achievements for it?
SELECT 
  COUNT(*) as total_achievements,
  platform,
  MIN(created_at) as first_added
FROM achievements
WHERE game_title_id IN (SELECT id FROM game_titles WHERE name ILIKE '%talos%')
GROUP BY platform;

-- 3. Is it in your user_games?
SELECT 
  gt.name,
  p.code as platform,
  ug.total_trophies,
  ug.earned_trophies,
  ug.completion_percent,
  ug.statusxp_effective
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE gt.name ILIKE '%talos%'
  AND ug.user_id = (SELECT id FROM profiles LIMIT 1);

-- 4. Have you earned any achievements for it?
SELECT 
  a.name,
  a.psn_trophy_type,
  ua.earned_at
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE gt.name ILIKE '%talos%'
  AND ua.user_id = (SELECT id FROM profiles LIMIT 1)
ORDER BY ua.earned_at
LIMIT 5;
