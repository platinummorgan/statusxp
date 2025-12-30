-- Simple check: what are the actual values?
SELECT 
  SUM(base_statusxp) as old_base_calc,
  SUM(statusxp_effective) as new_effective_calc,
  COUNT(*) as total_games,
  COUNT(*) FILTER (WHERE statusxp_effective = 0) as games_with_zero_effective,
  COUNT(*) FILTER (WHERE base_statusxp IS NULL) as games_with_null_base
FROM user_games
WHERE user_id = '3d0e9a9d-8d01-45e5-bceb-d851dad8af13';
