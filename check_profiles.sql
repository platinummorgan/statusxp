-- Check profiles table for all users
SELECT 
  id,
  username,
  display_name,
  display_platform,
  psn_online_id,
  psn_avatar_url,
  xbox_gamertag,
  steam_display_name,
  avatar_url
FROM profiles
LIMIT 10;

-- Check if xbox_gamertag and steam_display_name columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('xbox_gamertag', 'steam_display_name', 'psn_avatar_url');
