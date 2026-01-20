-- ============================================================================
-- Backfill user_progress for Steam games from user_achievements
-- ============================================================================
-- Steam sync populated achievements but not user_progress
-- This creates the missing game progress records
-- ============================================================================

INSERT INTO user_progress (
  user_id,
  platform_id,
  platform_game_id,
  achievements_earned,
  total_achievements,
  completion_percentage,
  current_score,
  last_played_at,
  metadata
)
SELECT 
  ua.user_id,
  ua.platform_id,
  ua.platform_game_id,
  COUNT(*) as achievements_earned,
  (
    SELECT COUNT(*)
    FROM achievements a
    WHERE a.platform_id = ua.platform_id
      AND a.platform_game_id = ua.platform_game_id
  ) as total_achievements,
  ROUND(
    (COUNT(*)::NUMERIC / NULLIF((
      SELECT COUNT(*)
      FROM achievements a
      WHERE a.platform_id = ua.platform_id
        AND a.platform_game_id = ua.platform_game_id
    ), 0) * 100), 2
  ) as completion_percentage,
  0 as current_score,  -- Steam doesn't have a score system like Xbox
  MAX(ua.earned_at) as last_played_at,
  '{}'::jsonb as metadata
FROM user_achievements ua
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 5  -- Steam
  AND NOT EXISTS (
    -- Don't insert if already exists
    SELECT 1 FROM user_progress up
    WHERE up.user_id = ua.user_id
      AND up.platform_id = ua.platform_id
      AND up.platform_game_id = ua.platform_game_id
  )
GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id;

-- Verify the insert
SELECT COUNT(*) as steam_games_added FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 5;

-- Test get_user_grouped_games now returns Steam
SELECT 
  name,
  (platforms[1]->>'code') as platform,
  (platforms[1]->>'earned_trophies')::int as earned,
  (platforms[1]->>'total_trophies')::int as total
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid)
WHERE (platforms[1]->>'code') = 'Steam'
LIMIT 10;
