-- Check current leaderboard state
SELECT 
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.last_updated
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
ORDER BY lc.total_statusxp DESC
LIMIT 20;

-- Check YOUR calculation specifically
SELECT 
  p.display_name,
  SUM(calc.statusxp_effective)::bigint as calculated_statusxp,
  COUNT(DISTINCT (calc.platform_id, calc.platform_game_id)) as game_count
FROM profiles p
CROSS JOIN LATERAL calculate_statusxp_with_stacks(p.id) calc
WHERE p.display_name = 'Dex-Morgan'
GROUP BY p.id, p.display_name;

-- Sample of your games with stack multipliers
SELECT 
  calc.platform_id,
  calc.platform_game_id,
  calc.statusxp_raw,
  calc.stack_index,
  calc.stack_multiplier,
  calc.statusxp_effective
FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a') calc
ORDER BY calc.statusxp_effective DESC
LIMIT 30;

-- Check if there are achievements not being counted
SELECT 
  ua.platform_id,
  COUNT(DISTINCT ua.platform_game_id) as games_with_achievements,
  COUNT(*) as total_achievements
FROM user_achievements ua
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY ua.platform_id;
