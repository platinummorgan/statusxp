-- FIX: Put Dex-Morgan back on leaderboards

-- Set show_on_leaderboard to true and fix display_name
UPDATE profiles 
SET 
  show_on_leaderboard = true,
  display_name = 'Dex-Morgan'
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Refresh all leaderboard caches
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_psn_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_xbox_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_steam_cache;

-- Verify you're back
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  p.display_name,
  p.show_on_leaderboard,
  p.psn_online_id
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check your rank
SELECT 
  COUNT(*) + 1 as your_rank,
  (SELECT total_statusxp FROM leaderboard_cache WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') as your_statusxp,
  (SELECT COUNT(*) FROM leaderboard_cache) as total_users
FROM leaderboard_cache
WHERE total_statusxp > (SELECT total_statusxp FROM leaderboard_cache WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a');
