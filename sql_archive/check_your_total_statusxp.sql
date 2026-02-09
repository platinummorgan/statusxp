-- Check YOUR total StatusXP

-- 1. Total from user_progress (what leaderboard uses)
SELECT 
  'From user_progress' as source,
  SUM(up.current_score) as total_statusxp,
  COUNT(*) as games_with_data
FROM user_progress up
WHERE up.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';

-- 2. Total from achievements (recalculated)
SELECT 
  'From achievements' as source,
  ROUND(SUM(a.base_status_xp * a.rarity_multiplier))::integer as total_statusxp,
  COUNT(DISTINCT a.platform_game_id) as games_in_achievements
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND a.include_in_score = true;

-- 3. Check games with achievements but NO user_progress record
SELECT 
  COUNT(DISTINCT ua.platform_game_id) as games_missing_progress
FROM (
  SELECT DISTINCT platform_id, platform_game_id
  FROM user_achievements
  WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
) ua
LEFT JOIN user_progress up ON 
  up.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND up.platform_id = ua.platform_id
  AND up.platform_game_id = ua.platform_game_id
WHERE up.user_id IS NULL;

-- 4. List games with achievements but missing user_progress
SELECT 
  ua.platform_id,
  ua.platform_game_id,
  COUNT(*) as achievement_count,
  ROUND(SUM(a.base_status_xp * a.rarity_multiplier))::integer as expected_statusxp
FROM (
  SELECT DISTINCT platform_id, platform_game_id, user_id
  FROM user_achievements
  WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
) ua_distinct
JOIN user_achievements ua ON 
  ua.user_id = ua_distinct.user_id
  AND ua.platform_id = ua_distinct.platform_id
  AND ua.platform_game_id = ua_distinct.platform_game_id
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
LEFT JOIN user_progress up ON 
  up.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND up.platform_id = ua_distinct.platform_id
  AND up.platform_game_id = ua_distinct.platform_game_id
WHERE up.user_id IS NULL
  AND a.include_in_score = true
GROUP BY ua.platform_id, ua.platform_game_id
ORDER BY expected_statusxp DESC;
