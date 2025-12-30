-- Refresh the leaderboard cache to show correct numbers
REFRESH MATERIALIZED VIEW leaderboard_cache;

-- Verify Dex-Morgan's numbers in the cache
SELECT 
  p.username,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.unique_games
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE p.username = 'Dex-Morgan';
