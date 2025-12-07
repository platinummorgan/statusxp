-- Migrate PSN trophy unlocks from user_trophies to user_achievements
-- This connects your existing PSN trophy unlocks to the new achievements table

INSERT INTO user_achievements (user_id, achievement_id, platform, unlocked_at)
SELECT 
  ut.user_id,
  a.id as achievement_id,
  'psn' as platform,
  ut.earned_at
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
JOIN game_titles gt ON t.game_title_id = gt.id
JOIN achievements a ON 
  a.game_title_id = gt.id 
  AND a.platform = 'psn'
  AND a.platform_achievement_id = t.psn_trophy_id::text
WHERE NOT EXISTS (
  -- Don't duplicate if already exists
  SELECT 1 FROM user_achievements ua2
  WHERE ua2.user_id = ut.user_id
    AND ua2.achievement_id = a.id
)
ON CONFLICT (user_id, achievement_id) DO NOTHING;

-- Show migration results
SELECT 
  'Migrated PSN trophy unlocks' as message,
  COUNT(*) as count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.platform = 'psn';
