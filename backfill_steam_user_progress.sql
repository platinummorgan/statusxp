-- Check if user_progress exists for Steam games
SELECT 
  'user_progress for Steam' as check_name,
  COUNT(*) as count
FROM user_progress
WHERE platform_id = 4
  AND user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');

-- Check how many unique Steam games you have achievements for
SELECT 
  'Unique Steam games from achievements' as check_name,
  COUNT(DISTINCT platform_game_id) as count
FROM user_achievements
WHERE platform_id = 4
  AND user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');

-- Backfill user_progress for Steam games
INSERT INTO user_progress (
  user_id,
  platform_id,
  platform_game_id,
  total_achievements,
  achievements_earned,
  completion_percentage,
  first_played_at,
  last_played_at,
  synced_at,
  metadata
)
SELECT 
  ua.user_id,
  ua.platform_id,
  ua.platform_game_id,
  a.total_count,
  a.earned_count,
  CASE 
    WHEN a.total_count > 0 THEN ROUND((a.earned_count::numeric / a.total_count::numeric) * 100, 2)
    ELSE 0
  END as completion_percentage,
  NOW() as first_played_at,
  NOW() as last_played_at,
  NOW() as synced_at,
  jsonb_build_object(
    'backfilled', true,
    'backfilled_at', NOW()
  ) as metadata
FROM user_achievements ua
JOIN (
  SELECT 
    platform_id,
    platform_game_id,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE EXISTS (
      SELECT 1 FROM user_achievements ua2 
      WHERE ua2.platform_id = achievements.platform_id 
        AND ua2.platform_game_id = achievements.platform_game_id
        AND ua2.platform_achievement_id = achievements.platform_achievement_id
        AND ua2.user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com')
    )) as earned_count
  FROM achievements
  WHERE platform_id = 4
  GROUP BY platform_id, platform_game_id
) a ON a.platform_id = ua.platform_id AND a.platform_game_id = ua.platform_game_id
WHERE ua.user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com')
  AND ua.platform_id = 4
  AND NOT EXISTS (
    SELECT 1 FROM user_progress up
    WHERE up.user_id = ua.user_id
      AND up.platform_id = ua.platform_id
      AND up.platform_game_id = ua.platform_game_id
  )
GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id, a.total_count, a.earned_count;

-- Verify backfill
SELECT 
  'After backfill - user_progress count' as check_name,
  COUNT(*) as count
FROM user_progress
WHERE platform_id = 4
  AND user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');
