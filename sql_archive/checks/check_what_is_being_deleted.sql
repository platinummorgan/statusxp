-- Check if user_achievements rows are being deleted or achievements metadata is corrupted

-- 1. Count TOTAL user_achievements for PSN (should not be decreasing)
SELECT COUNT(*) as total_user_achievements_psn
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 1;

-- 2. Count achievements with platinum flag
SELECT COUNT(*) as achievements_with_platinum_flag
FROM achievements
WHERE platform_id = 1
  AND metadata->>'psn_trophy_type' = 'platinum';

-- 3. Check for user_achievements that don't have matching achievements record
SELECT COUNT(*) as orphaned_user_achievements
FROM user_achievements ua
LEFT JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND a.platform_achievement_id IS NULL;

-- 4. Check for achievements that recently changed from platinum to non-platinum
-- (Look for achievements with "platinum" in name but trophy_type is not platinum)
SELECT 
  platform_game_id,
  platform_achievement_id,
  name,
  metadata->>'psn_trophy_type' as trophy_type,
  metadata
FROM achievements
WHERE platform_id = 1
  AND (LOWER(name) LIKE '%platinum%' OR metadata->>'is_platinum' = 'true')
  AND metadata->>'psn_trophy_type' != 'platinum'
LIMIT 10;

-- 5. Sample recent achievements to check metadata structure
SELECT 
  platform_game_id,
  platform_achievement_id,
  name,
  metadata,
  created_at
FROM achievements
WHERE platform_id = 1
  AND created_at > NOW() - INTERVAL '3 hours'
ORDER BY created_at DESC
LIMIT 20;
