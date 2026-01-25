-- StatusXP leaderboard snapshot and cross-check

-- 1) Current StatusXP leaderboard (top 50)
SELECT 
  lc.user_id,
  p.username,
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.last_updated
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
ORDER BY lc.total_statusxp DESC
LIMIT 50;

-- 2) Raw StatusXP totals from calculate_statusxp_with_stacks (top 50)
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  COALESCE(t.total_statusxp, 0) as total_statusxp,
  COALESCE(t.total_games, 0) as total_game_entries
FROM profiles p
LEFT JOIN LATERAL (
  SELECT 
    COUNT(*)::integer as total_games,
    COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp
  FROM calculate_statusxp_with_stacks(p.id)
) t ON true
WHERE p.show_on_leaderboard = true
  AND p.merged_into_user_id IS NULL
ORDER BY total_statusxp DESC
LIMIT 50;

-- 3) Compare cached vs raw for a specific user (replace username)
SELECT 
  p.id as user_id,
  p.username,
  lc.total_statusxp as cached_statusxp,
  t.total_statusxp as raw_statusxp
FROM profiles p
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
LEFT JOIN LATERAL (
  SELECT COALESCE(SUM(statusxp_effective), 0)::bigint as total_statusxp
  FROM calculate_statusxp_with_stacks(p.id)
) t ON true
WHERE p.username = 'lprovencher1';
