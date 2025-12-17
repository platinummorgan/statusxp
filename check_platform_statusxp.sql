-- Check total StatusXP by platform for current user

-- 1. StatusXP breakdown by platform
SELECT 
  p.name as platform,
  p.code,
  COUNT(DISTINCT ug.game_title_id) as games,
  SUM(ug.earned_trophies) as achievements_earned,
  SUM(ug.total_trophies) as achievements_total,
  SUM(ug.statusxp_raw) as raw_statusxp,
  SUM(ug.statusxp_effective) as effective_statusxp,
  ROUND(AVG(ug.completion_percent), 2) as avg_completion
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY p.name, p.code
ORDER BY effective_statusxp DESC;

-- 2. Grand total
SELECT 
  COUNT(DISTINCT ug.game_title_id) as total_games,
  SUM(ug.earned_trophies) as total_achievements,
  SUM(ug.statusxp_effective) as total_statusxp
FROM user_games ug
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1);

-- 3. Top 10 games by StatusXP
SELECT 
  gt.name as game,
  p.name as platform,
  ug.earned_trophies,
  ug.total_trophies,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.completion_percent
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
ORDER BY ug.statusxp_effective DESC
LIMIT 10;
