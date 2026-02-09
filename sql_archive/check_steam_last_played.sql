-- Check Steam games in user_progress
SELECT 
  g.name,
  up.last_played_at,
  up.metadata->>'last_played' as metadata_last_played
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id 
  AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND up.platform_id = 4
ORDER BY up.last_played_at DESC NULLS LAST
LIMIT 10;
