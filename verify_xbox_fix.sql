-- Verify the fix worked
SELECT 
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check that metadata was backfilled
SELECT 
  COUNT(*) as total_games,
  COUNT(CASE WHEN metadata->>'current_gamerscore' IS NOT NULL THEN 1 END) as games_with_gamerscore,
  SUM((metadata->>'current_gamerscore')::integer) as total_gamerscore_from_metadata
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12);
