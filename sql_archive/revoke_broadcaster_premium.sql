-- Revoke premium from broadcaster (you shouldn't get auto-premium for owning the channel)
UPDATE user_premium_status
SET 
  is_premium = false,
  premium_source = null,
  premium_expires_at = NOW(),
  updated_at = NOW()
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'; -- mdorminey79@gmail.com (broadcaster)

-- Verify results
SELECT 
  p.id,
  au.email,
  p.twitch_user_id,
  ups.is_premium,
  ups.premium_source,
  ups.premium_expires_at
FROM profiles p
JOIN auth.users au ON au.id = p.id
LEFT JOIN user_premium_status ups ON ups.user_id = p.id
WHERE p.twitch_user_id IS NOT NULL
ORDER BY ups.is_premium DESC;
