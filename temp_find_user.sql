SELECT 
  id, 
  username, 
  display_name, 
  psn_online_id, 
  xbox_gamertag, 
  steam_display_name,
  twitch_user_id,
  created_at
FROM profiles 
WHERE username ILIKE '%samanater%' 
   OR display_name ILIKE '%samanater%' 
   OR psn_online_id ILIKE '%samanater%' 
   OR xbox_gamertag ILIKE '%samanater%' 
   OR steam_display_name ILIKE '%samanater%'
ORDER BY created_at DESC
LIMIT 10;
