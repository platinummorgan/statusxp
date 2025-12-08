-- Check my rarity data to see if Rare Air should be unlocking
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- 1. Check PSN trophies with rarity
SELECT 
  'PSN' as platform,
  COUNT(*) FILTER (WHERE t.rarity_global IS NOT NULL AND t.rarity_global > 0) as with_rarity,
  COUNT(*) FILTER (WHERE t.rarity_global < 5) as under_5_percent,
  COUNT(*) FILTER (WHERE t.rarity_global < 2) as under_2_percent,
  COUNT(*) FILTER (WHERE t.rarity_global < 1) as under_1_percent,
  MIN(CASE WHEN t.rarity_global > 0 THEN t.rarity_global END) as rarest
FROM trophies t
JOIN user_trophies ut ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 2. Check Xbox achievements with rarity
SELECT 
  'Xbox' as platform,
  COUNT(*) FILTER (WHERE a.rarity_global IS NOT NULL AND a.rarity_global > 0) as with_rarity,
  COUNT(*) FILTER (WHERE a.rarity_global < 5) as under_5_percent,
  COUNT(*) FILTER (WHERE a.rarity_global < 2) as under_2_percent,
  COUNT(*) FILTER (WHERE a.rarity_global < 1) as under_1_percent,
  MIN(CASE WHEN a.rarity_global > 0 THEN a.rarity_global END) as rarest
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'xbox';

-- 3. Check Steam achievements with rarity
SELECT 
  'Steam' as platform,
  COUNT(*) FILTER (WHERE a.rarity_global IS NOT NULL AND a.rarity_global > 0) as with_rarity,
  COUNT(*) FILTER (WHERE a.rarity_global < 5) as under_5_percent,
  COUNT(*) FILTER (WHERE a.rarity_global < 2) as under_2_percent,
  COUNT(*) FILTER (WHERE a.rarity_global < 1) as under_1_percent,
  MIN(CASE WHEN a.rarity_global > 0 THEN a.rarity_global END) as rarest
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'steam';

-- 4. Show some examples of rare trophies I have
SELECT 
  'PSN' as platform,
  gt.name as game,
  t.name as trophy_name,
  t.tier,
  t.rarity_global as rarity_percent
FROM trophies t
JOIN user_trophies ut ON ut.trophy_id = t.id
JOIN game_titles gt ON gt.id = t.game_title_id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.rarity_global IS NOT NULL
  AND t.rarity_global < 5
ORDER BY t.rarity_global ASC
LIMIT 10;

-- 5. Check what the achievement checker is looking for
-- This is what the Dart code queries
SELECT COUNT(*) as count_under_5_percent
FROM user_trophies ut
JOIN trophies t ON t.id = ut.trophy_id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.rarity_global < 5.0
  AND t.rarity_global IS NOT NULL;

-- 6. Check if achievement is already unlocked
SELECT achievement_id, unlocked_at
FROM user_meta_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND achievement_id = 'rare_air';
