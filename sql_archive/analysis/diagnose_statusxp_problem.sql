-- Compare your calculation vs Otaku's
SELECT 
  'Dex-Morgan' as user_name,
  SUM(calc.statusxp_effective)::bigint as calculated_statusxp,
  COUNT(DISTINCT (calc.platform_id, calc.platform_game_id)) as game_count,
  AVG(calc.statusxp_effective)::integer as avg_per_game
FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a') calc

UNION ALL

SELECT 
  'Otaku' as user_name,
  SUM(calc.statusxp_effective)::bigint as calculated_statusxp,
  COUNT(DISTINCT (calc.platform_id, calc.platform_game_id)) as game_count,
  AVG(calc.statusxp_effective)::integer as avg_per_game
FROM calculate_statusxp_with_stacks((SELECT id FROM profiles WHERE display_name = 'Otaku EVO IX')) calc;

-- Check achievements per platform for both users
SELECT 
  'Dex-Morgan' as user_name,
  ua.platform_id,
  COUNT(DISTINCT ua.platform_game_id) as games,
  COUNT(*) as achievements
FROM user_achievements ua
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY ua.platform_id

UNION ALL

SELECT 
  'Otaku' as user_name,
  ua.platform_id,
  COUNT(DISTINCT ua.platform_game_id) as games,
  COUNT(*) as achievements
FROM user_achievements ua
WHERE ua.user_id = (SELECT id FROM profiles WHERE display_name = 'Otaku EVO IX')
GROUP BY ua.platform_id
ORDER BY user_name, platform_id;

-- Check if achievements have include_in_score = false
SELECT 
  a.platform_id,
  COUNT(*) FILTER (WHERE a.include_in_score = true) as included,
  COUNT(*) FILTER (WHERE a.include_in_score = false) as excluded,
  COUNT(*) as total
FROM achievements a
GROUP BY a.platform_id
ORDER BY a.platform_id;

-- Sample Otaku's stack calculation
SELECT 
  platform_id,
  platform_game_id,
  statusxp_raw,
  stack_index,
  stack_multiplier,
  statusxp_effective
FROM calculate_statusxp_with_stacks((SELECT id FROM profiles WHERE display_name = 'Otaku EVO IX'))
ORDER BY statusxp_effective DESC
LIMIT 20;
