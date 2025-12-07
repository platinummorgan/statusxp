-- COMPLETE MIGRATION: Move remaining PSN trophies to user_achievements
-- This will migrate all trophies from user_trophies that aren't already in user_achievements

-- First, let's see how many we'll be migrating
SELECT COUNT(*) as trophies_to_migrate
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE NOT EXISTS (
  SELECT 1 FROM user_achievements ua
  JOIN achievements a ON ua.achievement_id = a.id
  WHERE ua.user_id = ut.user_id
    AND a.game_title_id = t.game_title_id
    AND a.platform = 'psn'
    AND a.platform_achievement_id = t.psn_trophy_id::text
);

-- Now do the actual migration
-- This inserts into user_achievements by matching old trophies to new achievements
INSERT INTO user_achievements (user_id, achievement_id, platform, unlocked_at)
SELECT DISTINCT
  ut.user_id,
  a.id as achievement_id,
  'psn' as platform,
  ut.earned_at as unlocked_at
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
JOIN achievements a ON (
  a.game_title_id = t.game_title_id 
  AND a.platform = 'psn'
  AND a.platform_achievement_id = t.psn_trophy_id::text
)
WHERE NOT EXISTS (
  SELECT 1 FROM user_achievements ua2
  WHERE ua2.user_id = ut.user_id
    AND ua2.achievement_id = a.id
)
ON CONFLICT (user_id, achievement_id) DO NOTHING;

-- Verify the migration
SELECT 
  COUNT(*) as total_achievements,
  COUNT(*) FILTER (WHERE a.psn_trophy_type = 'platinum') as platinum_count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'psn';
