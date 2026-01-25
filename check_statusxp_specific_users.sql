-- Compare cached vs raw StatusXP for specific users

SELECT 
  p.username,
  p.display_name,
  lc.total_statusxp as cached_statusxp,
  raw.total_statusxp as raw_statusxp,
  lc.total_game_entries as cached_games,
  raw.total_games as raw_games
FROM profiles p
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
LEFT JOIN LATERAL (
  SELECT 
    COUNT(*)::integer as total_games,
    COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp
  FROM calculate_statusxp_with_stacks(p.id)
) raw ON true
WHERE p.username IN ('Dex-Morgan');
