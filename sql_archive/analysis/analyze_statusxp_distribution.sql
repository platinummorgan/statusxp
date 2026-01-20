-- Compare achievement quality across top users
SELECT 
  p.display_name,
  ua.platform_id,
  COUNT(DISTINCT ua.platform_game_id) as games,
  COUNT(*) as total_achievements,
  SUM(a.base_status_xp)::BIGINT as total_statusxp,
  ROUND(AVG(a.base_status_xp), 2) as avg_statusxp_per_achievement,
  ROUND(SUM(a.base_status_xp) / COUNT(DISTINCT ua.platform_game_id), 2) as avg_statusxp_per_game
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE p.display_name IN ('X_imThumper_X', 'Dex-Morgan', 'Otaku EVO IX')
  AND a.include_in_score = true
GROUP BY p.display_name, ua.platform_id
ORDER BY p.display_name, ua.platform_id;

-- Check if base_status_xp is being calculated correctly
SELECT 
  platform_id,
  COUNT(*) as achievement_count,
  MIN(base_status_xp) as min_statusxp,
  MAX(base_status_xp) as max_statusxp,
  ROUND(AVG(base_status_xp), 2) as avg_statusxp,
  COUNT(*) FILTER (WHERE base_status_xp IS NULL) as null_count,
  COUNT(*) FILTER (WHERE base_status_xp = 0) as zero_count
FROM achievements
WHERE include_in_score = true
GROUP BY platform_id
ORDER BY platform_id;

-- Sample of achievements with their StatusXP values
SELECT 
  platform_id,
  name,
  rarity_global,
  rarity_multiplier,
  base_status_xp,
  include_in_score
FROM achievements
WHERE include_in_score = true
ORDER BY RANDOM()
LIMIT 30;
