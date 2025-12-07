-- Check if Xbox avatar is now saved
SELECT 
  xbox_avatar_url,
  steam_avatar_url,
  psn_avatar_url
FROM profiles
LIMIT 1;
