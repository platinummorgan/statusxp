-- Check your avatar URLs (replace YOUR_USER_ID with your actual ID)
SELECT 
  xbox_avatar_url,
  steam_avatar_url,
  psn_avatar_url
FROM profiles
LIMIT 1;
