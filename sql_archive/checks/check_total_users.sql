-- Check total user count
SELECT COUNT(*) as total_users
FROM auth.users;

-- Get user breakdown by platform
SELECT 
  CASE 
    WHEN psn_account_id IS NOT NULL THEN 'PSN'
    WHEN xbox_gamertag IS NOT NULL THEN 'Xbox'
    WHEN steam_id IS NOT NULL THEN 'Steam'
    ELSE 'No Platform'
  END as platform,
  COUNT(*) as user_count
FROM profiles
GROUP BY 
  CASE 
    WHEN psn_account_id IS NOT NULL THEN 'PSN'
    WHEN xbox_gamertag IS NOT NULL THEN 'Xbox'
    WHEN steam_id IS NOT NULL THEN 'Steam'
    ELSE 'No Platform'
  END
ORDER BY user_count DESC;

-- Check premium users
SELECT 
  COUNT(*) FILTER (WHERE is_premium = true) as premium_users,
  COUNT(*) FILTER (WHERE is_premium = false OR is_premium IS NULL) as free_users,
  COUNT(*) as total
FROM user_premium_status;

-- Recent signups (last 7 days)
SELECT 
  DATE(created_at) as signup_date,
  COUNT(*) as new_users
FROM auth.users
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY signup_date DESC;
