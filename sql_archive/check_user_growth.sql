-- User Growth Analysis

-- 1. Daily signups over time
SELECT 
  DATE(created_at) as signup_date,
  COUNT(*) as new_users,
  SUM(COUNT(*)) OVER (ORDER BY DATE(created_at)) as cumulative_users
FROM profiles
WHERE created_at IS NOT NULL
GROUP BY DATE(created_at)
ORDER BY signup_date DESC
LIMIT 60;

-- 2. Monthly growth summary
SELECT 
  DATE_TRUNC('month', created_at) as month,
  COUNT(*) as new_users,
  SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', created_at)) as cumulative_users
FROM profiles
WHERE created_at IS NOT NULL
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- 3. Overall stats
SELECT 
  COUNT(*) as total_users,
  MIN(created_at) as first_user_signup,
  MAX(created_at) as most_recent_signup,
  ROUND(EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 86400, 1) as days_active,
  ROUND(COUNT(*)::numeric / NULLIF(EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 86400, 0), 2) as avg_signups_per_day
FROM profiles
WHERE created_at IS NOT NULL;

-- 4. Weekly breakdown (last 12 weeks)
SELECT 
  DATE_TRUNC('week', created_at) as week_start,
  COUNT(*) as new_users,
  SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('week', created_at)) as cumulative_users
FROM profiles
WHERE created_at IS NOT NULL
  AND created_at >= NOW() - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week_start DESC;
