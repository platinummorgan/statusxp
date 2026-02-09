-- Find where 6775 Gamerscore actually is
-- Check user_progress metadata for gamerscore values
SELECT 
  platform_id,
  COUNT(*) as game_count,
  SUM((metadata->>'current_gamerscore')::integer) as sum_current_gamerscore,
  SUM((metadata->>'max_gamerscore')::integer) as sum_max_gamerscore
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
  AND metadata->>'max_gamerscore' IS NOT NULL
GROUP BY platform_id;

-- Check if there's a profiles column with total gamerscore
SELECT 
  xbox_gamertag,
  psn_online_id,
  steam_display_name
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Sample a few games to see metadata structure
SELECT 
  platform_id,
  platform_game_id,
  completion_percentage,
  current_score,
  metadata
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
LIMIT 5;
