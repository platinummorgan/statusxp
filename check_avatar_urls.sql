-- Check if avatar URLs are populated
SELECT 
  id,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  preferred_display_platform,
  psn_avatar_url IS NOT NULL as has_psn_avatar,
  xbox_avatar_url IS NOT NULL as has_xbox_avatar,
  steam_avatar_url IS NOT NULL as has_steam_avatar,
  xbox_avatar_url,
  steam_avatar_url
FROM profiles
WHERE id = auth.uid();
