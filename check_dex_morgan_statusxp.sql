-- StatusXP for DEX-MORGAN (your real account)

-- 1. Total StatusXP by platform
SELECT 
  p.name as platform,
  COUNT(DISTINCT ug.game_title_id) as games,
  SUM(ug.earned_trophies) as achievements_earned,
  SUM(ug.statusxp_effective) as total_statusxp
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'  -- Dex-Morgan
GROUP BY p.name
ORDER BY total_statusxp DESC;

-- 2. Grand total
SELECT 
  COUNT(DISTINCT game_title_id) as total_games,
  SUM(earned_trophies) as total_achievements,
  SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 3. Games with incomplete trophies
SELECT 
  gt.name,
  p.code as platform,
  ug.earned_trophies,
  ug.total_trophies,
  ug.completion_percent
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.completion_percent < 100
ORDER BY ug.completion_percent DESC
LIMIT 20;
