-- EMERGENCY: Check if Dex-Morgan's data is actually gone or just not showing

-- 1. How many total achievements do you have RIGHT NOW?
SELECT COUNT(*) as total_achievements
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 2. How many PSN achievements RIGHT NOW?
SELECT COUNT(*) as psn_achievements
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 1;

-- 3. How many platinums RIGHT NOW (checking if metadata exists)?
SELECT 
  COUNT(*) as platinum_count,
  COUNT(CASE WHEN a.metadata IS NULL THEN 1 END) as null_metadata,
  COUNT(CASE WHEN a.metadata->>'trophy_type' IS NULL THEN 1 END) as null_trophy_type
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND a.metadata->>'trophy_type' = 'platinum';

-- 4. Check what's in the achievements table - does metadata exist?
SELECT 
  COUNT(*) as total_psn_achievements,
  COUNT(CASE WHEN metadata IS NOT NULL THEN 1 END) as has_metadata,
  COUNT(CASE WHEN metadata->>'trophy_type' IS NOT NULL THEN 1 END) as has_trophy_type
FROM achievements
WHERE platform_id = 1
LIMIT 1;

-- 5. Sample: Show me 5 random PSN achievements to see structure
SELECT 
  platform_achievement_id,
  name,
  metadata
FROM achievements
WHERE platform_id = 1
LIMIT 5;
