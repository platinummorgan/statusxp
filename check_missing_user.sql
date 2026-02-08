-- Check if this user exists
SELECT 
  u.id,
  u.email,
  u.created_at as user_created,
  p.id as profile_id,
  p.username,
  p.created_at as profile_created
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE u.id = 'ff194d87-37d5-4219-a71d-a52bb81709e6';

-- Also check if there's leaderboard data for them
SELECT 
  user_id,
  total_statusxp,
  potential_statusxp
FROM leaderboard_cache
WHERE user_id = 'ff194d87-37d5-4219-a71d-a52bb81709e6';
