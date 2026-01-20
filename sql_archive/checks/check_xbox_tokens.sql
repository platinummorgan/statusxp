-- Check Xbox token fields in profiles table
SELECT 
  id,
  display_name,
  xbox_gamertag,
  CASE WHEN xbox_access_token IS NOT NULL THEN 'Has token' ELSE 'No token' END as access_token_status,
  CASE WHEN xbox_refresh_token IS NOT NULL THEN 'Has refresh' ELSE 'No refresh' END as refresh_token_status,
  LENGTH(xbox_access_token) as token_length,
  updated_at
FROM profiles
WHERE xbox_gamertag IS NOT NULL
ORDER BY updated_at DESC;
