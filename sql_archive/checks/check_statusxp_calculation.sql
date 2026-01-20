-- Check StatusXP calculation methods

-- Method 1: Using base_status_xp field (should be the correct method)
SELECT 
  SUM(a.base_status_xp) as statusxp_from_base_field,
  COUNT(*) as total_achievements
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.include_in_score = true;

-- Method 2: Using rarity tiers (old method - produces high numbers)
SELECT 
  SUM(
    CASE 
      WHEN a.rarity_global <= 1.0 THEN 300
      WHEN a.rarity_global <= 5.0 THEN 225
      WHEN a.rarity_global <= 10.0 THEN 175
      WHEN a.rarity_global <= 25.0 THEN 125
      WHEN a.rarity_global > 25.0 THEN 100
      ELSE 100
    END
  ) as statusxp_from_rarity_tiers
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.include_in_score = true;

-- Check what the leaderboard_global_cache view is showing
SELECT statusxp 
FROM leaderboard_global_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
