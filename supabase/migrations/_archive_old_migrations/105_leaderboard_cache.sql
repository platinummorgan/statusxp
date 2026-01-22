-- Create a materialized view for fast leaderboard queries
CREATE MATERIALIZED VIEW IF NOT EXISTS leaderboard_cache AS
SELECT 
  ug.user_id,
  SUM(ug.statusxp_effective) as total_statusxp,
  COUNT(*) as total_game_entries,
  COUNT(DISTINCT ug.game_title_id) as unique_games,
  MAX(ug.updated_at) as last_game_update
FROM user_games ug
GROUP BY ug.user_id;

-- Create index for fast lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_cache_user ON leaderboard_cache(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_cache_statusxp ON leaderboard_cache(total_statusxp DESC);

-- Refresh the view
REFRESH MATERIALIZED VIEW leaderboard_cache;

-- Test it
SELECT 
  p.username,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.unique_games
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE p.username = 'Dex-Morgan';
