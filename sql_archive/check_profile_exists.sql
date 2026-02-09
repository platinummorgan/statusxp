-- Check if profile exists for your user
SELECT 
  u.id as user_id,
  u.email,
  p.id as profile_id,
  p.username,
  p.total_statusxp,
  p.psn_online_id,
  p.created_at as profile_created
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE u.email = 'mdorminey79@gmail.com';

-- Check if there's a mismatch between auth.users and profiles
SELECT 
  'Missing profiles' as issue_type,
  COUNT(*) as count
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE p.id IS NULL;
