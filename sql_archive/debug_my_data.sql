-- Debug: Check what's actually in the database for Dex-Morgan
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- 1. Check total achievements by platform
SELECT 
  ua.platform_id,
  COUNT(*) as achievement_count,
  COUNT(DISTINCT ua.platform_game_id) as game_count
FROM user_achievements ua
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY ua.platform_id
ORDER BY ua.platform_id;

-- 2. Check PSN trophies specifically
SELECT 
  a.metadata->>'trophy_type' as trophy_type,
  COUNT(*) as count
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
GROUP BY a.metadata->>'trophy_type';

-- 3. Check what the view is actually returning
SELECT * FROM psn_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 4. Check StatusXP calculation - what are your base_status_xp values?
SELECT 
  a.base_status_xp,
  COUNT(*) as achievement_count,
  SUM(a.base_status_xp) as total_xp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY a.base_status_xp
ORDER BY a.base_status_xp;

-- 5. Check rarity-based calculation vs base_status_xp
SELECT 
  'Using base_status_xp' as method,
  SUM(COALESCE(a.base_status_xp, 0)) as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'

UNION ALL

SELECT 
  'Using rarity_global' as method,
  SUM(
    CASE 
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 1.0 THEN 300
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 5.0 THEN 225
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 10.0 THEN 175
      WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 25.0 THEN 125
      WHEN a.rarity_global IS NOT NULL THEN 100
      ELSE 100
    END
  ) as total_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
