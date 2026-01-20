-- Populate missing user_progress entries for Dex-Morgan
-- This should fix the sync treating games as "new" every time

INSERT INTO user_progress (
  user_id,
  platform_id,
  platform_game_id,
  achievements_earned,
  total_achievements,
  completion_percentage,
  synced_at
)
SELECT 
  '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid as user_id,
  g.platform_id,
  g.platform_game_id,
  COUNT(ua.platform_achievement_id) as achievements_earned,
  (SELECT COUNT(*) FROM achievements a 
   WHERE a.platform_id = g.platform_id 
   AND a.platform_game_id = g.platform_game_id) as total_achievements,
  ROUND((COUNT(ua.platform_achievement_id)::NUMERIC / NULLIF(
    (SELECT COUNT(*) FROM achievements a 
     WHERE a.platform_id = g.platform_id 
     AND a.platform_game_id = g.platform_game_id), 0
  ) * 100), 2) as completion_percentage,
  NOW() as synced_at
FROM user_achievements ua
INNER JOIN games g ON 
  g.platform_id = ua.platform_id 
  AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1  -- PSN only
  AND NOT EXISTS (
    SELECT 1 FROM user_progress up 
    WHERE up.user_id = ua.user_id 
    AND up.platform_id = ua.platform_id 
    AND up.platform_game_id = ua.platform_game_id
  )
GROUP BY g.platform_id, g.platform_game_id
ON CONFLICT (user_id, platform_id, platform_game_id) DO NOTHING;

-- Check how many we added
SELECT COUNT(*) as total_user_progress_now
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 1;
