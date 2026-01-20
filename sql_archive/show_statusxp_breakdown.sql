-- Show breakdown of StatusXP by platform
SELECT 
  CASE p.id
    WHEN 1 THEN 'PlayStation'
    WHEN 10 THEN 'Xbox 360 (stack 1-3)'
    WHEN 11 THEN 'Xbox One (stack 1-3)'
    WHEN 12 THEN 'Xbox Series (stack 1-3)'
    ELSE p.name
  END as platform,
  COUNT(*) as game_count,
  SUM(statusxp_effective) as total_statusxp,
  ROUND(AVG(statusxp_effective), 2) as avg_per_game,
  SUM(CASE WHEN stack_index = 1 THEN 1 ELSE 0 END) as base_games,
  SUM(CASE WHEN stack_index > 1 THEN 1 ELSE 0 END) as stacked_games
FROM calculate_statusxp_with_stacks('8fef7fd4-581d-4ef9-9d48-482eff31c69d') calc
JOIN platforms p ON p.id = calc.platform_id
GROUP BY p.id, p.name
ORDER BY total_statusxp DESC;

-- Also show unique base games (Xbox counted once)
WITH unique_games AS (
  SELECT 
    CASE 
      WHEN platform_id IN (10, 11, 12) THEN platform_game_id
      ELSE platform_id::text || '_' || platform_game_id
    END as game_key,
    MAX(statusxp_effective) as max_stack_xp
  FROM calculate_statusxp_with_stacks('8fef7fd4-581d-4ef9-9d48-482eff31c69d')
  WHERE stack_index = 1
  GROUP BY game_key
)
SELECT 
  COUNT(*) as unique_base_games,
  SUM(max_stack_xp) as statusxp_from_base_games
FROM unique_games;
