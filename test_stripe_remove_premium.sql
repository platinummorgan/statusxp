-- Temporarily remove premium status for testing
UPDATE user_premium_status
SET is_premium = false
WHERE user_id = (
  SELECT id 
  FROM auth.users 
  WHERE email = 'mdorminey79@gmail.com' -- Replace with your email
);

-- Check the result
SELECT 
  u.email,
  ups.is_premium,
  ups.premium_since,
  ups.premium_expires_at
FROM auth.users u
LEFT JOIN user_premium_status ups ON u.id = ups.user_id
WHERE u.email = 'mdorminey79@gmail.com';
