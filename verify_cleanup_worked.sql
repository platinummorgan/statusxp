-- Verify cleanup worked for your account

-- 1. Check your total game count (should be ~369 instead of 699)
SELECT COUNT(*) as my_total_games
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 2. Check Star Wars Jedi entries (should only show PS5 now, not PS4/PS3)
SELECT 
  up.platform_id,
  up.platform_game_id,
  g.name,
  up.achievements_earned,
  up.total_achievements
FROM user_progress up
JOIN games g ON up.platform_id = g.platform_id AND up.platform_game_id = g.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND g.platform_game_id = 'NPWR23631_00'
ORDER BY up.platform_id;

-- 3. Check for any remaining duplicates in your account
SELECT 
  platform_game_id,
  COUNT(*) as duplicate_count,
  STRING_AGG(platform_id::text, ', ') as platforms
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_game_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
