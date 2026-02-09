-- Debug: Why is Otaku showing 22.2M gamerscore?

-- 1. Check Otaku's actual achievement count and calculated gamerscore
SELECT 
  COUNT(*) as achievement_count,
  SUM(a.score_value) as total_gamerscore,
  AVG(a.score_value) as avg_score_per_achievement
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '1dab84fc-e06c-44b6-ae34-7e36a5179583'  -- Otaku
  AND ua.platform_id IN (10, 11, 12);

-- 2. Check if there are achievements with abnormally high score_value
SELECT 
  a.platform_game_id,
  a.name,
  a.score_value,
  COUNT(*) as times_earned
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '1dab84fc-e06c-44b6-ae34-7e36a5179583'
  AND ua.platform_id IN (10, 11, 12)
  AND a.score_value > 1000  -- Xbox achievements are usually 5-100G
ORDER BY a.score_value DESC
LIMIT 20;

-- 3. Check for duplicate achievement records for Otaku
SELECT 
  ua.platform_id,
  ua.platform_game_id,
  ua.platform_achievement_id,
  COUNT(*) as duplicate_count,
  MAX(a.score_value) as score_value
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '1dab84fc-e06c-44b6-ae34-7e36a5179583'
  AND ua.platform_id IN (10, 11, 12)
GROUP BY ua.platform_id, ua.platform_game_id, ua.platform_achievement_id
HAVING COUNT(*) > 1
LIMIT 20;

-- 4. Sample of Otaku's achievements with normal score_values
SELECT 
  a.platform_game_id,
  a.name,
  a.score_value
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '1dab84fc-e06c-44b6-ae34-7e36a5179583'
  AND ua.platform_id IN (10, 11, 12)
ORDER BY a.score_value DESC
LIMIT 30;
