-- Analytics Debug Queries
-- Run these in Supabase SQL Editor to see actual counts
-- Replace 'YOUR_USER_ID' with your actual user_id from profiles table

-- 1. Check what's in user_achievements with platform breakdown
SELECT 
  a.platform,
  COUNT(*) as count
FROM user_achievements ua
LEFT JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY a.platform
ORDER BY count DESC;

-- 2. Check user_achievements WITHOUT join (see if achievements table is missing data)
SELECT COUNT(*) as total_user_achievements
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 3. Check how many have NULL achievement_id (orphaned records)
SELECT COUNT(*) as orphaned_records
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
AND achievement_id IS NULL;

-- 4. Check user_trophies count (old table)
SELECT COUNT(*) as user_trophies_count
FROM user_trophies
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 5. Check PSN trophy types (from user_achievements)
SELECT 
  a.psn_trophy_type,
  COUNT(*) as count
FROM user_achievements ua
LEFT JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
AND a.platform = 'psn'
GROUP BY a.psn_trophy_type
ORDER BY count DESC;

-- 6. Sample 10 records to see structure
SELECT 
  ua.id,
  ua.achievement_id,
  ua.earned_at,
  a.platform,
  a.psn_trophy_type,
  a.name
FROM user_achievements ua
LEFT JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
LIMIT 10;
