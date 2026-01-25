-- Audit your StatusXP scores specifically

-- 1. What's in your user_progress table (current per-game scores)
SELECT 
  up.platform_id,
  up.platform_game_id,
  up.current_score as stored_statusxp,
  up.achievements_earned,
  SUM(a.base_status_xp * a.rarity_multiplier) as recalculated_statusxp
FROM user_progress up
LEFT JOIN user_achievements ua ON 
  ua.user_id = up.user_id 
  AND ua.platform_id = up.platform_id 
  AND ua.platform_game_id = up.platform_game_id
LEFT JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
  AND a.include_in_score = true
WHERE up.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'  -- XxlmThumperxX
GROUP BY up.user_id, up.platform_id, up.platform_game_id, up.current_score, up.achievements_earned
ORDER BY up.current_score DESC
LIMIT 30;

-- 2. Total StatusXP across all games - what should it be?
SELECT 
  'Stored in user_progress' as source,
  SUM(up.current_score) as total_statusxp
FROM user_progress up
WHERE up.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
UNION ALL
SELECT 
  'Recalculated from achievements' as source,
  ROUND(SUM(a.base_status_xp * a.rarity_multiplier))::integer as total_statusxp
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND a.include_in_score = true;

-- 3. Check base_status_xp values for your achievements (are they reasonable?)
SELECT 
  ROUND(a.base_status_xp, 1) as base_xp_rounded,
  COUNT(*) as achievement_count,
  AVG(a.rarity_global) as avg_rarity,
  MIN(a.rarity_global) as min_rarity,
  MAX(a.rarity_global) as max_rarity
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND a.include_in_score = true
GROUP BY ROUND(a.base_status_xp, 1)
ORDER BY base_xp_rounded DESC;

-- 4. Sample of your actual achievements
SELECT 
  a.name,
  a.rarity_global,
  a.base_status_xp,
  a.rarity_multiplier,
  ROUND(a.base_status_xp * a.rarity_multiplier, 2) as final_xp,
  a.include_in_score
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
ORDER BY a.base_status_xp * a.rarity_multiplier DESC
LIMIT 50;
