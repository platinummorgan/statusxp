-- Check why your duplicates weren't cleaned up
WITH your_duplicates AS (
  SELECT 
    up.platform_id,
    up.platform_game_id,
    g.name,
    MIN(ua.earned_at) as first_earned,
    MAX(ua.earned_at) as last_earned,
    MAX(ua.earned_at) - MIN(ua.earned_at) as time_between
  FROM user_progress up
  JOIN games g ON up.platform_id = g.platform_id AND up.platform_game_id = g.platform_game_id
  LEFT JOIN user_achievements ua ON up.user_id = ua.user_id 
    AND up.platform_id = ua.platform_id 
    AND up.platform_game_id = ua.platform_game_id
  WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND up.platform_game_id IN (
      SELECT platform_game_id 
      FROM user_progress 
      WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
      GROUP BY platform_game_id 
      HAVING COUNT(*) > 1
    )
  GROUP BY up.platform_id, up.platform_game_id, g.name
)
SELECT 
  platform_game_id,
  name,
  COUNT(*) as platforms_count,
  STRING_AGG(platform_id::text, ', ' ORDER BY platform_id) as platform_ids,
  MIN(first_earned) as earliest_achievement,
  MAX(last_earned) as latest_achievement,
  MAX(last_earned) - MIN(first_earned) as total_time_span,
  CASE 
    WHEN MAX(last_earned) - MIN(first_earned) < INTERVAL '7 days' THEN 'BUG (should have been deleted)'
    WHEN MAX(last_earned) - MIN(first_earned) >= INTERVAL '180 days' THEN 'LEGITIMATE STACK'
    ELSE 'UNCLEAR'
  END as classification
FROM your_duplicates
GROUP BY platform_game_id, name
ORDER BY classification, name
LIMIT 50;
