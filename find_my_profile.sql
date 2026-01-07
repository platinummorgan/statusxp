-- Find Dex-Morgan profile
SELECT 
  id,
  username,
  display_name,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  preferred_display_platform,
  show_on_leaderboard,
  created_at,
  (SELECT COUNT(*) FROM user_games WHERE user_id = profiles.id) as game_count,
  (SELECT COALESCE(SUM(statusxp_effective), 0) FROM user_games WHERE user_id = profiles.id) as total_statusxp
FROM profiles
WHERE psn_online_id = 'Dex-Morgan'
   OR xbox_gamertag ILIKE 'Dex%Morgan%'
   OR steam_display_name ILIKE 'Dex%Morgan%';

-- After running above, use the user_id to fix leaderboard visibility:
-- Replace YOUR_USER_ID_HERE with the actual UUID from the result above

-- UPDATE profiles 
-- SET 
--   show_on_leaderboard = true,
--   display_name = COALESCE(
--     NULLIF(display_name, ''),
--     psn_online_id,
--     xbox_gamertag,
--     steam_display_name
--   ),
--   preferred_display_platform = COALESCE(
--     NULLIF(preferred_display_platform, ''),
--     'psn'
--   )
-- WHERE id = 'YOUR_USER_ID_HERE';

-- Then refresh caches:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
