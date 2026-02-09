-- Check all users with linked Twitch accounts and their premium status
SELECT 
  p.id,
  au.email,
  p.twitch_user_id,
  ups.is_premium,
  ups.premium_since,
  ups.premium_expires_at,
  ups.updated_at
FROM profiles p
JOIN auth.users au ON au.id = p.id
LEFT JOIN user_premium_status ups ON ups.user_id = p.id
WHERE p.twitch_user_id IS NOT NULL
ORDER BY p.created_at DESC;
