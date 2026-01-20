-- Find games that were recently synced and might have lost platinums
-- Check which games were synced in the last hour and compare counts

WITH recent_syncs AS (
  SELECT 
    platform_game_id,
    achievements_earned,
    total_achievements,
    synced_at,
    metadata
  FROM user_progress
  WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND platform_id = 1
    AND synced_at > NOW() - INTERVAL '2 hours'
  ORDER BY synced_at DESC
),
actual_counts AS (
  SELECT 
    ua.platform_game_id,
    COUNT(*) as actual_earned,
    g.name as game_name
  FROM user_achievements ua
  INNER JOIN games g ON 
    g.platform_id = ua.platform_id 
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND ua.platform_id = 1
  GROUP BY ua.platform_game_id, g.name
)
SELECT 
  rs.platform_game_id,
  ac.game_name,
  rs.achievements_earned as user_progress_count,
  ac.actual_earned as actual_user_achievements,
  (ac.actual_earned - rs.achievements_earned) as discrepancy,
  rs.synced_at,
  rs.metadata->>'has_platinum' as has_platinum_flag
FROM recent_syncs rs
LEFT JOIN actual_counts ac ON ac.platform_game_id = rs.platform_game_id
WHERE ac.actual_earned != rs.achievements_earned
OR ac.actual_earned IS NULL
ORDER BY rs.synced_at DESC;

-- Count total platinums RIGHT NOW
SELECT COUNT(*) as current_platinum_count
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND a.metadata->>'psn_trophy_type' = 'platinum';
