-- Run this in Supabase SQL Editor to see what data we actually have
-- This will help us understand the platform distribution

SELECT 
  a.platform,
  COUNT(DISTINCT ua.id) as achievement_count,
  COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) as platinum_count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY a.platform
ORDER BY a.platform;

-- Also check game counts per platform
SELECT 
  platform,
  COUNT(*) as game_count
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform
ORDER BY platform;
