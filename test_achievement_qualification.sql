-- Test query to manually check what achievements a user should have
-- Run this to see what your current stats qualify for

WITH user_stats AS (
  SELECT 
    '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid as user_id,
    COUNT(*) as total_achievements,
    COUNT(*) FILTER (WHERE t.rarity_global < 5.0) as rare_5_count,
    COUNT(*) FILTER (WHERE t.rarity_global < 2.0) as rare_2_count,
    COUNT(*) FILTER (WHERE t.rarity_global < 1.0) as rare_1_count
  FROM user_trophies ut
  JOIN trophies t ON t.id = ut.trophy_id
  WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
),
game_stats AS (
  SELECT
    '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid as user_id,
    COUNT(*) as total_games,
    COUNT(*) FILTER (WHERE has_platinum = true) as platinum_count,
    COUNT(DISTINCT platform_id) as platform_count
  FROM user_games
  WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
)
SELECT 
  'Volume Achievements' as category,
  CASE 
    WHEN us.total_achievements >= 2500 THEN 'No Life, Great Life (2500+)'
    WHEN us.total_achievements >= 1000 THEN 'Achievement Engine (1000+)'
    WHEN us.total_achievements >= 500 THEN 'XP Machine (500+)'
    WHEN us.total_achievements >= 250 THEN 'On the Grind (250+)'
    WHEN us.total_achievements >= 50 THEN 'Warming Up (50+)'
    ELSE 'None yet - need 50 trophies'
  END as qualification,
  us.total_achievements as your_count
FROM user_stats us

UNION ALL

SELECT 
  'Rarity Achievements',
  CASE 
    WHEN us.rare_5_count >= 10 THEN 'Mythic Hunter (10 < 5%)'
    WHEN us.rare_5_count >= 5 THEN 'Diamond Hands (5 < 5%)'
    WHEN us.rare_1_count >= 1 THEN 'One-Percenter (1 < 1%)'
    WHEN us.rare_2_count >= 1 THEN 'Baller (1 < 2%)'
    WHEN us.rare_5_count >= 1 THEN 'Rare Air (1 < 5%)'
    ELSE 'None yet - earn rare trophies'
  END,
  us.rare_5_count
FROM user_stats us

UNION ALL

SELECT 
  'Platinum Achievements',
  CASE 
    WHEN gs.platinum_count >= 50 THEN 'Legendary Finisher (50+)'
    WHEN gs.platinum_count >= 25 THEN 'Certified Platinum (25+)'
    WHEN gs.platinum_count >= 10 THEN 'Double Digits (10+)'
    ELSE 'None yet - need ' || (10 - gs.platinum_count)::text || ' more platinums'
  END,
  gs.platinum_count
FROM game_stats gs

UNION ALL

SELECT 
  'Platform Achievements',
  CASE 
    WHEN gs.platform_count >= 3 THEN 'Triforce (all 3 platforms)'
    WHEN gs.platform_count >= 1 THEN 'Welcome achievement unlocked'
    ELSE 'None yet - sync a platform'
  END,
  gs.platform_count
FROM game_stats gs;
