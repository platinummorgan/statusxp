-- Check actual current_score values in user_progress for sanders.geoff
SELECT 
  up.platform_id,
  up.platform_game_id,
  g.name as game_name,
  up.achievements_earned,
  up.total_achievements,
  up.current_score,
  up.metadata->>'max_gamerscore' as max_gamerscore
FROM user_progress up
LEFT JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889'
  AND up.platform_id IN (10, 11, 12)  -- Xbox platforms
ORDER BY up.current_score DESC
LIMIT 20;

-- Run calculate_statusxp_with_stacks to see what current_score SHOULD be
SELECT 
  platform_id,
  game_name,
  achievements_earned,
  statusxp_effective,
  stack_index,
  stack_multiplier
FROM calculate_statusxp_with_stacks('ca9dc5a7-34a6-4a71-8659-d28da82de889')
WHERE platform_id IN (10, 11, 12)
ORDER BY statusxp_effective DESC
LIMIT 20;
