-- List all users with their platinum counts

SELECT 
  id,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  display_name,
  (SELECT COUNT(*) FROM user_games WHERE user_id = profiles.id AND platinum_trophies > 0 AND platform_id = 1) as psn_platinum_count,
  created_at
FROM profiles
ORDER BY psn_platinum_count DESC NULLS LAST, created_at DESC;
