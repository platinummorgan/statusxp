-- Test what base_status_xp values would give us 15,570 total
-- Using the ACTUAL base_status_xp field instead of rarity tiers

SELECT 
  'Current (rarity tiers 100/125/175/225/300)' as method,
  SUM(
    CASE 
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 1.0 THEN 300
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 5.0 THEN 225
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 10.0 THEN 175
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 25.0 THEN 125
      WHEN a.rarity_global IS NOT NULL THEN 100
      ELSE 100
    END
  ) as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid

UNION ALL

SELECT 
  'Using base_status_xp (current values 5/7/9/12/15)' as method,
  SUM(a.base_status_xp) as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;
