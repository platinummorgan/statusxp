-- Check platinum counts from different angles

-- 1. Count platinums via user_achievements join
SELECT COUNT(*) as platinum_via_user_achievements
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.platform = 'psn' 
  AND a.psn_trophy_type = 'platinum';

-- 2. Count all PSN platinum achievements (regardless of who earned them)
SELECT COUNT(*) as total_platinum_achievements
FROM achievements
WHERE platform = 'psn' 
  AND psn_trophy_type = 'platinum';

-- 3. Check if is_platinum flag matches psn_trophy_type
SELECT 
  COUNT(*) as total_psn_achievements,
  COUNT(*) FILTER (WHERE psn_trophy_type = 'platinum') as type_is_platinum,
  COUNT(*) FILTER (WHERE is_platinum = true) as flag_is_platinum,
  COUNT(*) FILTER (WHERE psn_trophy_type = 'platinum' AND is_platinum = true) as both_match,
  COUNT(*) FILTER (WHERE psn_trophy_type = 'platinum' AND is_platinum IS NULL) as platinum_but_null_flag
FROM achievements
WHERE platform = 'psn';

-- 4. Sample of platinums to verify data
SELECT 
  a.name,
  a.psn_trophy_type,
  a.is_platinum,
  ua.earned_at
FROM achievements a
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE a.platform = 'psn' 
  AND a.psn_trophy_type = 'platinum'
LIMIT 10;
