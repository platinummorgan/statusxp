-- Check RLS policies on user_achievements
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'user_achievements';

-- Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'user_achievements';

-- Try to manually insert a test achievement for DanyGT37
-- First, get an achievement ID
SELECT a.id, a.name, gt.name as game_name
FROM achievements a
INNER JOIN game_titles gt ON gt.id = a.game_title_id
WHERE a.platform = 'steam' 
  AND a.game_title_id IN (
    SELECT game_title_id FROM user_games 
    WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455' 
    AND platform_id = 4
  )
LIMIT 1;
