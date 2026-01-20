-- Scale down base_status_xp to achieve ~15k total StatusXP for Dex-Morgan
-- Current: 194,339 StatusXP from base_status_xp
-- Target: ~15,000 StatusXP
-- Scale factor: 15,000 / 194,339 = 0.0772

-- Update all achievements to scaled values
UPDATE achievements
SET base_status_xp = GREATEST(1, ROUND(base_status_xp * 0.0772))
WHERE base_status_xp > 0;

-- Verify the result for Dex-Morgan
SELECT 
  SUM(a.base_status_xp) as new_statusxp_total,
  COUNT(*) as total_achievements
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.include_in_score = true;
