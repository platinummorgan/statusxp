-- ============================================================================
-- Verify Steam games after sync
-- ============================================================================
-- Check if Steam data now exists and is being returned correctly
-- ============================================================================

-- 1. Check Steam games in user_progress
SELECT 
  'Steam Games in user_progress' as check_type,
  COUNT(*) as game_count,
  SUM(achievements_earned) as total_achievements_earned,
  SUM(total_achievements) as total_achievements_available
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' 
  AND platform_id = 5;

-- 2. Sample of Steam games
SELECT 
  g.name,
  up.achievements_earned,
  up.total_achievements,
  up.completion_percentage,
  up.current_score,
  up.last_played_at
FROM user_progress up
INNER JOIN games g ON g.platform_id = up.platform_id 
  AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND up.platform_id = 5
ORDER BY up.last_played_at DESC NULLS LAST
LIMIT 10;

-- 3. Test get_user_grouped_games function returns Steam
SELECT 
  name,
  (platforms[1]->>'code') as platform,
  (platforms[1]->>'earned_trophies')::int as earned,
  (platforms[1]->>'total_trophies')::int as total,
  (platforms[1]->>'statusxp')::numeric as statusxp
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid)
WHERE (platforms[1]->>'code') = 'Steam'
ORDER BY last_played_at DESC NULLS LAST
LIMIT 10;

-- 4. Platform counts
SELECT 
  CASE 
    WHEN platform_id = 1 THEN 'PSN'
    WHEN platform_id = 5 THEN 'Steam'
    WHEN platform_id = 10 THEN 'Xbox360'
    WHEN platform_id = 11 THEN 'XboxOne'
    WHEN platform_id = 12 THEN 'XboxSeriesX'
    ELSE 'Other'
  END as platform,
  COUNT(*) as game_count
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_id
ORDER BY platform_id;
