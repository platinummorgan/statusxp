-- Manually unlock missing achievements that you qualify for
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Check what you should have but don't
WITH should_have AS (
  SELECT 'no_life_great_life' as achievement_id WHERE 
    (SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
    (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') >= 2500
  UNION ALL
  SELECT 'welcome_pc_grind' WHERE 
    (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 3) > 0
  UNION ALL
  SELECT 'triforce' WHERE 
    (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 1) > 0
    AND (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 2) > 0
    AND (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 3) > 0
  UNION ALL
  SELECT 'rank_up_irl' WHERE 
    (SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
    (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') >= 10000
),
already_unlocked AS (
  SELECT achievement_id FROM user_meta_achievements 
  WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
),
missing AS (
  SELECT s.achievement_id 
  FROM should_have s
  LEFT JOIN already_unlocked a ON s.achievement_id = a.achievement_id
  WHERE a.achievement_id IS NULL
)
-- Insert missing achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT 
  '84b60ad6-cb2c-484f-8953-bf814551fd7a',
  achievement_id,
  NOW()
FROM missing
ON CONFLICT (user_id, achievement_id) DO NOTHING
RETURNING achievement_id, unlocked_at;
