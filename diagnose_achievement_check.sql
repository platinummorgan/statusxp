-- Diagnostic: Check which achievements trigger the 22 notification
-- These are the ones that qualify but are already unlocked

-- Get all achievements user qualifies for (based on stats)
-- We'll compare this against what's already unlocked

-- 1. Check rarity achievements
WITH rarity_stats AS (
  SELECT 
    COUNT(*) FILTER (WHERE rarity_percent < 5) as rare_5,
    COUNT(*) FILTER (WHERE rarity_percent < 2) as rare_2,
    COUNT(*) FILTER (WHERE rarity_percent < 1) as rare_1
  FROM (
    -- PSN trophies
    SELECT t.rarity_percent
    FROM user_trophies ut
    JOIN trophies t ON t.id = ut.trophy_id
    WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    
    UNION ALL
    
    -- Xbox/Steam achievements
    SELECT a.rarity_global as rarity_percent
    FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  ) all_achievements
)
SELECT 
  'rare_air' as achievement_id,
  CASE WHEN rare_5 >= 1 THEN 'QUALIFIES' ELSE 'no' END as status,
  EXISTS(SELECT 1 FROM user_meta_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND achievement_id = 'rare_air') as is_unlocked
FROM rarity_stats
UNION ALL
SELECT 
  'baller' as achievement_id,
  CASE WHEN rare_2 >= 1 THEN 'QUALIFIES' ELSE 'no' END as status,
  EXISTS(SELECT 1 FROM user_meta_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND achievement_id = 'baller') as is_unlocked
FROM rarity_stats
UNION ALL
SELECT 
  'one_percenter' as achievement_id,
  CASE WHEN rare_1 >= 1 THEN 'QUALIFIES' ELSE 'no' END as status,
  EXISTS(SELECT 1 FROM user_meta_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND achievement_id = 'one_percenter') as is_unlocked
FROM rarity_stats
ORDER BY achievement_id;
