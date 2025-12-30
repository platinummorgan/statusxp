-- Check user's actual StatusXP from different sources
WITH user_calc AS (
  SELECT 
    SUM(statusxp_effective) as direct_sum,
    COUNT(*) as game_count
  FROM user_games
  WHERE user_id = '3d0e9a9d-8d01-45e5-bceb-d851dad8af13'
),
cache_data AS (
  SELECT total_statusxp, total_game_entries, unique_games
  FROM leaderboard_cache
  WHERE user_id = '3d0e9a9d-8d01-45e5-bceb-d851dad8af13'
),
base_calc AS (
  SELECT SUM(base_statusxp) as base_sum
  FROM user_games
  WHERE user_id = '3d0e9a9d-8d01-45e5-bceb-d851dad8af13'
)
SELECT 
  user_calc.direct_sum as statusxp_effective_total,
  user_calc.game_count,
  cache_data.total_statusxp as cache_total,
  cache_data.total_game_entries as cache_game_count,
  base_calc.base_sum as base_statusxp_total
FROM user_calc, cache_data, base_calc;
