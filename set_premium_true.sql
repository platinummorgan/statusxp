-- Set mdorminey79@gmail.com back to premium
UPDATE user_premium_status 
SET 
  is_premium = true,
  premium_since = NOW(),
  premium_expires_at = NULL,
  updated_at = NOW()
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');

-- Verify
SELECT is_premium, premium_since, premium_expires_at 
FROM user_premium_status 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');
