-- Refresh the leaderboard materialized view to show new users
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;

-- Verify the refresh worked - show top 10
SELECT 
  p.display_name,
  COALESCE(p.psn_online_id, p.xbox_gamertag, p.steam_display_name) as platform_name,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.unique_games,
  lc.last_game_update
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
ORDER BY lc.total_statusxp DESC
LIMIT 10;
