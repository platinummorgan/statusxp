-- Emergency diagnostic - why aren't PSN achievements being written?

-- 1. Verify RLS policies are correct
SELECT 
  'RLS Policies on user_achievements' as check,
  policyname,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'user_achievements'
  AND cmd = 'INSERT'
ORDER BY policyname;

-- 2. Check if PSN achievements exist in achievements table for test games
SELECT 
  'Achievements Available in DB' as check,
  gt.name as game_name,
  COUNT(a.id) as achievements_defined
FROM game_titles gt
INNER JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'psn'
WHERE gt.name IN ('Gems of War', 'DRAGON QUEST HEROES II', 'Terraria', 'DOGFIGHTER -WW2-', 'Sky: Children of the Light')
GROUP BY gt.name
ORDER BY gt.name;

-- 3. Check if there are any PSN achievements with errors or issues
SELECT 
  'PSN Achievements Validation' as check,
  COUNT(*) as total_psn_achievements,
  COUNT(*) FILTER (WHERE game_title_id IS NULL) as missing_game_link,
  COUNT(*) FILTER (WHERE platform_achievement_id IS NULL OR platform_achievement_id = '') as missing_platform_id
FROM achievements
WHERE platform = 'psn';

-- 4. Test manual insert with service role simulation
-- This will tell us if RLS is still blocking
INSERT INTO user_achievements (user_id, achievement_id, earned_at)
SELECT 
  '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid,
  a.id,
  NOW()
FROM achievements a
INNER JOIN game_titles gt ON gt.id = a.game_title_id
WHERE gt.name = 'Gems of War'
  AND a.platform = 'psn'
LIMIT 1
ON CONFLICT (user_id, achievement_id) DO NOTHING
RETURNING achievement_id;
