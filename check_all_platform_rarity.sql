-- Check rarity data across all platforms
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- PSN Trophies with rarity
SELECT 
  'PSN' as platform,
  COUNT(*) as total_trophies,
  COUNT(CASE WHEN rarity_global IS NOT NULL THEN 1 END) as with_rarity,
  ROUND(AVG(rarity_global)::numeric, 2) as avg_rarity,
  MIN(rarity_global) as rarest,
  MAX(rarity_global) as most_common
FROM trophies t
JOIN user_trophies ut ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'

UNION ALL

-- Xbox Achievements with rarity
SELECT 
  'Xbox' as platform,
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN rarity_global IS NOT NULL AND rarity_global > 0 THEN 1 END) as with_rarity,
  ROUND(AVG(CASE WHEN rarity_global > 0 THEN rarity_global END)::numeric, 2) as avg_rarity,
  MIN(CASE WHEN rarity_global > 0 THEN rarity_global END) as rarest,
  MAX(rarity_global) as most_common
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'xbox'

UNION ALL

-- Steam Achievements with rarity
SELECT 
  'Steam' as platform,
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN rarity_global IS NOT NULL AND rarity_global > 0 THEN 1 END) as with_rarity,
  ROUND(AVG(CASE WHEN rarity_global > 0 THEN rarity_global END)::numeric, 2) as avg_rarity,
  MIN(CASE WHEN rarity_global > 0 THEN rarity_global END) as rarest,
  MAX(rarity_global) as most_common
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'steam';

-- Show some examples of rarest achievements from each platform
SELECT 
  'PSN' as platform,
  gt.name as game,
  t.name as achievement_name,
  t.tier,
  t.rarity_global as rarity_percent
FROM trophies t
JOIN user_trophies ut ON ut.trophy_id = t.id
JOIN game_titles gt ON gt.id = t.game_title_id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.rarity_global IS NOT NULL
ORDER BY t.rarity_global ASC
LIMIT 5

UNION ALL

SELECT 
  'Xbox' as platform,
  gt.name as game,
  a.name as achievement_name,
  CAST(a.xbox_gamerscore AS TEXT) as tier,
  a.rarity_global as rarity_percent
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'xbox'
  AND a.rarity_global > 0
ORDER BY a.rarity_global ASC
LIMIT 5

UNION ALL

SELECT 
  'Steam' as platform,
  gt.name as game,
  a.name as achievement_name,
  'achievement' as tier,
  a.rarity_global as rarity_percent
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'steam'
  AND a.rarity_global > 0
ORDER BY a.rarity_global ASC
LIMIT 5;
