-- VISUAL EXPLANATION: How base_status_xp × rarity_multiplier creates differentiation

-- Show how the FINAL SCORE differs for each tier
SELECT 
  'Common (>25% rarity)' as tier,
  1 as base_status_xp,
  1.00 as rarity_multiplier,
  1 * 1.00 as final_score_per_achievement

UNION ALL SELECT 'Uncommon (10-25%)', 1, 1.25, 1 * 1.25
UNION ALL SELECT 'Rare (5-10%)', 1, 1.75, 1 * 1.75  
UNION ALL SELECT 'Very Rare (1-5%)', 1, 2.25, 1 * 2.25
UNION ALL SELECT 'Ultra Rare (≤1%)', 2, 3.00, 2 * 3.00;

-- Now show YOUR ACTUAL achievements and what they'll be worth
SELECT 
  CASE 
    WHEN a.rarity_multiplier::numeric = 1.00 THEN 'Common'
    WHEN a.rarity_multiplier::numeric = 1.25 THEN 'Uncommon'
    WHEN a.rarity_multiplier::numeric = 1.75 THEN 'Rare'
    WHEN a.rarity_multiplier::numeric = 2.25 THEN 'Very Rare'
    WHEN a.rarity_multiplier::numeric = 3.00 THEN 'Ultra Rare'
  END as tier,
  COUNT(*) as achievements_you_have,
  MAX(a.base_status_xp) as current_base_xp,
  MAX(a.rarity_multiplier::numeric) as multiplier,
  -- If we scale to 1/1/1/1/2:
  CASE 
    WHEN a.rarity_multiplier::numeric = 3.00 THEN 2
    ELSE 1
  END as new_base_xp,
  -- Final score per achievement after scaling:
  CASE 
    WHEN a.rarity_multiplier::numeric = 1.00 THEN 1.00
    WHEN a.rarity_multiplier::numeric = 1.25 THEN 1.25
    WHEN a.rarity_multiplier::numeric = 1.75 THEN 1.75
    WHEN a.rarity_multiplier::numeric = 2.25 THEN 2.25
    WHEN a.rarity_multiplier::numeric = 3.00 THEN 6.00
  END as points_per_achievement,
  -- Total for this tier:
  COUNT(*) * CASE 
    WHEN a.rarity_multiplier::numeric = 1.00 THEN 1.00
    WHEN a.rarity_multiplier::numeric = 1.25 THEN 1.25
    WHEN a.rarity_multiplier::numeric = 1.75 THEN 1.75
    WHEN a.rarity_multiplier::numeric = 2.25 THEN 2.25
    WHEN a.rarity_multiplier::numeric = 3.00 THEN 6.00
  END as total_points_from_tier
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
  AND a.base_status_xp > 0
GROUP BY a.rarity_multiplier::numeric
ORDER BY a.rarity_multiplier::numeric;
