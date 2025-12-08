-- Check if user profile exists and has data
SELECT 
  user_id,
  psn_online_id,
  psn_avatar_url,
  psn_is_plus,
  steam_display_name,
  steam_avatar_url,
  xbox_gamertag,
  xbox_avatar_url,
  preferred_display_platform
FROM user_profiles
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
