-- Check why user not in StatusXP leaderboard
-- Replace with Prov's user_id if needed
WITH target AS (
  SELECT id, username, display_name
  FROM profiles
  WHERE username = 'lprovencher1'
  LIMIT 1
)
SELECT 
  t.id as user_id,
  t.username,
  t.display_name,
  p.show_on_leaderboard,
  p.merged_into_user_id,
  (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = t.id) as total_achievements,
  (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = t.id AND ua.platform_id = 4) as steam_achievements,
  (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = t.id AND ua.platform_id IN (10,11,12)) as xbox_achievements,
  (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = t.id AND ua.platform_id IN (1,2,5,9)) as psn_achievements,
  (SELECT COUNT(*) FROM leaderboard_cache lc WHERE lc.user_id = t.id) as in_leaderboard_cache,
  (SELECT total_statusxp FROM leaderboard_cache lc WHERE lc.user_id = t.id) as total_statusxp
FROM target t
JOIN profiles p ON p.id = t.id;

-- Force refresh and re-check
SELECT refresh_statusxp_leaderboard();

SELECT lc.user_id, lc.total_statusxp, lc.total_game_entries, lc.last_updated
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE p.username = 'lprovencher1';
