-- Find the xdoscbobbles user and check their preferred_display_platform setting
-- This is the user showing as "Unknown" in position #7

SELECT 
  p.id,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  p.preferred_display_platform,
  p.show_on_leaderboard,
  au.email,
  lc.total_statusxp,
  lc.total_game_entries
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.id = 'c5ff31aa-8572-441a-ab09-22accd4c979b'
   OR au.email = 'oscarmargan20@gmail.com';
