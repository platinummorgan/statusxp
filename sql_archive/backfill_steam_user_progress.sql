-- Backfill user_progress for Steam games from user_achievements
-- This fixes the issue where Steam sync wrote achievements but not progress records
-- Run for user: 35029ccf-0d16-4741-a2fe-1e5b9fee4e23

INSERT INTO user_progress (
  user_id,
  platform_id,
  platform_game_id,
  current_score,
  achievements_earned,
  total_achievements,
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
  COUNT(*)::integer as current_score, -- For Steam, score = achievement count
  COUNT(*)::integer as achievements_earned,
  (
    SELECT COUNT(*)::integer
    FROM achievements a
    WHERE a.platform_id = ua.platform_id
      AND a.platform_game_id = ua.platform_game_id
  ) as total_achievements,
  (
    COUNT(*)::numeric / NULLIF(
      (SELECT COUNT(*) FROM achievements a 
       WHERE a.platform_id = ua.platform_id 
         AND a.platform_game_id = ua.platform_game_id), 0
    ) * 100
  )::numeric(5,2) as completion_percentage,
  MIN(ua.earned_at) as first_played_at,
  MAX(ua.earned_at) as last_played_at,
  NOW() as synced_at,
  jsonb_build_object(
    'backfilled_from_user_achievements', true,
    'backfill_date', NOW()
  ) as metadata
FROM user_achievements ua
WHERE ua.user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
  AND ua.platform_id = 4  -- Steam
  AND NOT EXISTS (
    SELECT 1 
    FROM user_progress up 
    WHERE up.user_id = ua.user_id 
      AND up.platform_id = ua.platform_id 
      AND up.platform_game_id = ua.platform_game_id
  )
GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id;

-- Verify the backfill worked
SELECT 
  COUNT(*) as steam_games_backfilled,
  SUM(achievements_earned) as total_achievements_backfilled
FROM user_progress
WHERE user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
  AND platform_id = 4;

