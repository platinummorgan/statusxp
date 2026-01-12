-- Check if webhook updated the premium status
SELECT 
  u.email,
  ups.is_premium,
  ups.premium_since,
  ups.premium_expires_at,
  ups.updated_at
FROM auth.users u
LEFT JOIN user_premium_status ups ON u.id = ups.user_id
WHERE u.email = 'mdorminey79@gmail.com';
