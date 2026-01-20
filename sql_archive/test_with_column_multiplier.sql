-- Test StatusXP with rarity_multiplier from COLUMN (not metadata)
SELECT 
  'base_status_xp only' as method,
  SUM(a.base_status_xp) as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid

UNION ALL

SELECT 
  'base_status_xp × rarity_multiplier (COLUMN)' as method,
  SUM(a.base_status_xp * a.rarity_multiplier::numeric)::bigint as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;
