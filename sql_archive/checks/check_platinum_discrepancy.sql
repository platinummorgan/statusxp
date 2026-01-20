-- Check platinum trophy discrepancy for Dex-Morgan

-- 1. Count using is_platinum flag
SELECT 
  'Using is_platinum flag' as method,
  COUNT(*) as platinum_count
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND a.metadata->>'is_platinum' = 'true'

UNION ALL

-- 2. Count using psn_trophy_type
SELECT 
  'Using psn_trophy_type' as method,
  COUNT(*) as platinum_count
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND a.metadata->>'psn_trophy_type' = 'platinum';

-- 3. Check if there are platinums with ONLY is_platinum (no psn_trophy_type)
SELECT 
  COUNT(*) as has_is_platinum_only,
  COUNT(CASE WHEN a.metadata->>'psn_trophy_type' IS NULL THEN 1 END) as missing_psn_trophy_type
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND a.metadata->>'is_platinum' = 'true';

-- 4. Sample platinums - show me 5 to see their metadata structure
SELECT 
  a.name,
  a.metadata
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND (a.metadata->>'is_platinum' = 'true' OR a.metadata->>'psn_trophy_type' = 'platinum')
LIMIT 10;
