-- Check xbox_leaderboard_cache last update
SELECT 
  user_id,
  gamerscore,
  achievement_count,
  last_updated
FROM xbox_leaderboard_cache
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Calculate actual current Gamerscore from metadata
SELECT 
  SUM((metadata->>'current_gamerscore')::integer) as calculated_from_metadata,
  SUM((metadata->>'max_gamerscore')::numeric * completion_percentage / 100) as estimated_from_completion
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12);

-- Find the function that updates xbox_leaderboard_cache
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%xbox%leaderboard%'
  OR routine_definition LIKE '%xbox_leaderboard_cache%';
