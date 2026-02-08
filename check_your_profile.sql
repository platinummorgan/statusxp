-- Check if your profile exists
SELECT 
  u.id as user_id,
  u.email,
  p.id as profile_id,
  p.username,
  p.total_statusxp
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE u.id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
