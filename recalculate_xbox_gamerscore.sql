-- Calculate actual current Gamerscore from completion percentage
SELECT 
  ROUND(SUM((metadata->>'max_gamerscore')::numeric * completion_percentage / 100))::integer as calculated_current_gamerscore,
  SUM((metadata->>'max_gamerscore')::integer) as max_possible_gamerscore,
  ROUND(AVG(completion_percentage), 2) as avg_completion_percent
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
  AND metadata->>'max_gamerscore' IS NOT NULL;

-- Update xbox_leaderboard_cache with the calculated value
UPDATE xbox_leaderboard_cache
SET 
  gamerscore = (
    SELECT ROUND(SUM((metadata->>'max_gamerscore')::numeric * completion_percentage / 100))::integer
    FROM user_progress
    WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
      AND platform_id IN (10, 11, 12)
      AND metadata->>'max_gamerscore' IS NOT NULL
  ),
  updated_at = NOW()
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Verify
SELECT gamerscore, achievement_count, updated_at
FROM xbox_leaderboard_cache
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
