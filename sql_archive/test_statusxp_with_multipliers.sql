-- Test StatusXP calculation WITH multipliers applied
-- This is how it SHOULD work based on your system

SELECT 
  'Just base_status_xp (no multipliers)' as method,
  SUM(a.base_status_xp) as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid

UNION ALL

SELECT 
  'With rarity_multiplier from metadata' as method,
  SUM(
    a.base_status_xp * 
    COALESCE((a.metadata->>'rarity_multiplier')::numeric, 1.0)
  )::bigint as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid

UNION ALL

SELECT 
  'With BOTH rarity_multiplier AND stack_multiplier' as method,
  SUM(
    a.base_status_xp * 
    COALESCE((a.metadata->>'rarity_multiplier')::numeric, 1.0) *
    COALESCE((a.metadata->>'stack_multiplier')::numeric, 1.0)
  )::bigint as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;
