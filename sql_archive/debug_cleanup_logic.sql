-- See what the cleanup script WOULD have identified for your user
-- (Simulating the games_to_delete logic)

-- PS5 duplicates with achievements < 7 days apart
SELECT DISTINCT 
  1 as platform_id, 
  g_ps5.platform_game_id,
  g_ps5.name,
  'PS5 duplicate' as reason
FROM games g_ps5
JOIN games g_ps4 ON g_ps5.platform_game_id = g_ps4.platform_game_id
WHERE g_ps5.platform_id = 1 AND g_ps4.platform_id = 2
  AND EXISTS (
    SELECT 1
    FROM user_achievements ua_ps5
    JOIN user_achievements ua_ps4 ON ua_ps5.user_id = ua_ps4.user_id
      AND ua_ps5.platform_game_id = ua_ps4.platform_game_id
    WHERE ua_ps5.platform_id = 1 
      AND ua_ps4.platform_id = 2
      AND ua_ps5.platform_game_id = g_ps5.platform_game_id
      AND ua_ps5.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'  -- YOUR user_id
      AND ABS(EXTRACT(EPOCH FROM (ua_ps5.earned_at - ua_ps4.earned_at))) < 604800
  )
LIMIT 20;

-- Check if user_achievements exist for one of your duplicate games
SELECT 
  user_id,
  platform_id,
  platform_game_id,
  platform_achievement_id,
  earned_at
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_game_id = 'NPWR15691_00'  -- 11-11: Memories Retold
ORDER BY platform_id, earned_at
LIMIT 10;
