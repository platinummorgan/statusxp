-- Debug script to check Steam achievements and StatusXP calculation

-- 1. Check if Steam achievements exist
SELECT COUNT(*) as steam_achievement_count
FROM achievements
WHERE platform = 'steam';

-- 2. Check if user has Steam achievements unlocked
SELECT COUNT(*) as my_steam_achievements
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.platform = 'steam'
  AND ua.user_id = (SELECT id FROM profiles LIMIT 1);

-- 3. Check Steam games in user_games
SELECT 
  gt.name,
  p.name as platform,
  ug.earned_trophies,
  ug.total_trophies,
  ug.statusxp_raw,
  ug.statusxp_effective
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE p.code = 'Steam'
  AND ug.user_id = (SELECT id FROM profiles LIMIT 1)
ORDER BY ug.created_at DESC;

-- 4. Check a sample Steam achievement with its StatusXP values
SELECT 
  a.name,
  a.rarity_global,
  a.rarity_band,
  a.base_status_xp,
  a.include_in_score,
  ua.earned_at
FROM achievements a
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id 
  AND ua.user_id = (SELECT id FROM profiles LIMIT 1)
WHERE a.platform = 'steam'
  AND ua.id IS NOT NULL
ORDER BY ua.earned_at DESC
LIMIT 10;

-- 5. Run the calculation function
SELECT calculate_user_game_statusxp();

-- 6. Check totals again by platform
SELECT 
  p.name as platform,
  COUNT(DISTINCT ug.game_title_id) as games,
  SUM(ug.earned_trophies) as achievements_earned,
  SUM(ug.statusxp_raw) as total_raw_xp,
  SUM(ug.statusxp_effective) as total_effective_xp
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY p.name
ORDER BY p.name;
