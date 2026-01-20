-- Backfill the 5 PSN test games' achievements for Dexmorgan6981
-- This verifies that the RLS fix is working correctly
-- Total: 5 achievements (1 per game)

-- User: Dexmorgan6981
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Games to backfill:
-- 1. Gems of War (1 trophy)
-- 2. DRAGON QUEST HEROES II (1 trophy)
-- 3. Terraria (1 trophy)
-- 4. DOGFIGHTER -WW2- (1 trophy)
-- 5. Sky: Children of the Light (1 trophy)

BEGIN;

-- Insert achievements for all 5 games
-- This should work with the fixed RLS policy
INSERT INTO user_achievements (user_id, achievement_id, earned_at)
SELECT 
  '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid as user_id,
  a.id as achievement_id,
  NOW() as earned_at
FROM achievements a
INNER JOIN game_titles gt ON gt.id = a.game_title_id
INNER JOIN user_games ug ON ug.game_title_id = gt.id 
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
WHERE gt.name IN (
  'Gems of War',
  'DRAGON QUEST HEROES II', 
  'Terraria',
  'DOGFIGHTER -WW2-',
  'Sky: Children of the Light'
)
AND a.platform = 'psn'
-- Only get the first earned achievement for each game based on user_games data
AND EXISTS (
  SELECT 1 FROM user_games ug2
  WHERE ug2.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
  AND ug2.game_title_id = gt.id
  AND ug2.earned_trophies >= 1
)
ON CONFLICT (user_id, achievement_id) DO NOTHING;

-- Verify the backfill
SELECT 
  'Backfill Results' as check,
  gt.name as game_name,
  COUNT(ua.achievement_id) as achievements_backfilled
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'psn'
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
AND gt.name IN (
  'Gems of War',
  'DRAGON QUEST HEROES II', 
  'Terraria',
  'DOGFIGHTER -WW2-',
  'Sky: Children of the Light'
)
GROUP BY gt.name
ORDER BY gt.name;

-- Show total achievement counts
SELECT 
  'Total Achievement Counts' as check,
  COUNT(*) FILTER (WHERE a.platform = 'psn') as psn_achievements,
  COUNT(*) FILTER (WHERE a.platform = 'xbox') as xbox_achievements,
  COUNT(*) FILTER (WHERE a.platform = 'steam') as steam_achievements,
  COUNT(*) as total_achievements
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;

COMMIT;
