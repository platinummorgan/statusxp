-- Check what platform IDs you actually have
SELECT 
  platform_id,
  COUNT(*) as game_count
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_id
ORDER BY platform_id;
