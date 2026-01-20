-- Compare achievement rarity distribution between X_imThumper_X and xdoscbobbles
-- This will show WHY someone with fewer games has more StatusXP

WITH user_achievement_breakdown AS (
  SELECT 
    p.psn_online_id as username,
    a.rarity_band,
    a.base_status_xp,
    COUNT(*) as achievement_count,
    SUM(a.base_status_xp) as total_statusxp_from_rarity
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  JOIN profiles p ON p.id = ua.user_id
  WHERE p.psn_online_id IN ('X_imThumper_X', 'xdoscbobbles')
  AND a.include_in_score = true
  GROUP BY p.psn_online_id, a.rarity_band, a.base_status_xp
)
SELECT 
  username,
  rarity_band,
  base_status_xp as points_per_achievement,
  achievement_count,
  total_statusxp_from_rarity,
  ROUND((achievement_count::numeric / SUM(achievement_count) OVER (PARTITION BY username) * 100), 1) as percentage_of_total
FROM user_achievement_breakdown
ORDER BY username, 
  CASE rarity_band
    WHEN 'ULTRA_RARE' THEN 1
    WHEN 'VERY_RARE' THEN 2
    WHEN 'RARE' THEN 3
    WHEN 'UNCOMMON' THEN 4
    WHEN 'COMMON' THEN 5
  END;
