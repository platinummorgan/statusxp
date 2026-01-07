-- Comprehensive platinum check for DaHead22

-- Check 1: Count by platinum_trophies > 0
SELECT COUNT(*) as platinum_trophies_count
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
  AND ug.platinum_trophies > 0;

-- Check 2: Count by has_platinum = true
SELECT COUNT(*) as has_platinum_count
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
  AND ug.has_platinum = true;

-- Check 3: Count from user_stats table
SELECT COALESCE(us.platinum_count, 0) as user_stats_platinum_count
FROM profiles p
LEFT JOIN user_stats us ON us.user_id = p.id
WHERE p.psn_online_id = 'DaHead22';

-- Show ALL games with ANY platinum indicator (uncomment to run separately)
/*
SELECT 
  gt.name,
  ug.platform_id,
  ug.platinum_trophies,
  ug.has_platinum,
  ug.completion_percent,
  ug.earned_trophies,
  ug.total_trophies
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND (ug.platinum_trophies > 0 OR ug.has_platinum = true)
ORDER BY ug.platform_id, gt.name;
*/
