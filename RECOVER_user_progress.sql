-- INSTANT RECOVERY: Populate user_progress from existing user_achievements data
-- This avoids another 3-hour sync by using the 17,912 achievements already saved

-- Step 1: Populate user_progress from aggregated achievement data
INSERT INTO user_progress (
  user_id, 
  platform_id, 
  platform_game_id, 
  achievements_earned, 
  total_achievements, 
  completion_percentage,
  last_played_at,
  synced_at,
  metadata
)
SELECT 
  user_id,
  platform_id,
  platform_game_id,
  COUNT(*) FILTER (WHERE earned_at IS NOT NULL) as achievements_earned,
  COUNT(*) as total_achievements,
  ROUND((COUNT(*) FILTER (WHERE earned_at IS NOT NULL)::numeric / COUNT(*)::numeric * 100), 2) as completion_percentage,
  MAX(earned_at) as last_played_at,
  NOW() as synced_at,
  jsonb_build_object(
    'last_rarity_sync', NOW(),
    'sync_failed', false,
    'last_sync_attempt', NOW()
  ) as metadata
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY user_id, platform_id, platform_game_id
ON CONFLICT (user_id, platform_id, platform_game_id) 
DO UPDATE SET
  achievements_earned = EXCLUDED.achievements_earned,
  total_achievements = EXCLUDED.total_achievements,
  completion_percentage = EXCLUDED.completion_percentage,
  last_played_at = EXCLUDED.last_played_at,
  synced_at = EXCLUDED.synced_at,
  metadata = EXCLUDED.metadata;

-- Step 2: Verify the recovery
SELECT COUNT(*) as games_recovered,
       SUM(achievements_earned) as total_earned,
       SUM(total_achievements) as total_achievements,
       ROUND(AVG(completion_percentage), 2) as avg_completion
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Step 3: Show sample of recovered data
SELECT platform_game_id, 
       achievements_earned, 
       total_achievements, 
       completion_percentage
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY achievements_earned DESC
LIMIT 10;
