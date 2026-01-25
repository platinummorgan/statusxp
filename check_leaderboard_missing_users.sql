-- Users with achievements but missing from StatusXP leaderboard_cache
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  p.show_on_leaderboard,
  COUNT(DISTINCT ua.platform_game_id) as games_with_achievements,
  COUNT(*) as total_achievements
FROM profiles p
JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
  AND lc.user_id IS NULL
GROUP BY p.id, p.username, p.display_name, p.show_on_leaderboard
ORDER BY total_achievements DESC;

-- Users with user_progress but zero current_score (won't be inserted)
SELECT 
  up.user_id,
  p.username,
  p.display_name,
  COUNT(*) as progress_rows,
  SUM(CASE WHEN up.current_score > 0 THEN 1 ELSE 0 END) as rows_with_score
FROM user_progress up
JOIN profiles p ON p.id = up.user_id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY up.user_id, p.username, p.display_name
HAVING SUM(CASE WHEN up.current_score > 0 THEN 1 ELSE 0 END) = 0
ORDER BY progress_rows DESC;

-- Recent sync errors from profiles
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  p.psn_sync_status,
  p.psn_sync_error,
  p.xbox_sync_status,
  p.xbox_sync_error,
  p.steam_sync_status,
  p.steam_sync_error,
  p.updated_at
FROM profiles p
WHERE p.merged_into_user_id IS NULL
  AND (
    p.psn_sync_status = 'error'
    OR p.xbox_sync_status = 'error'
    OR p.steam_sync_status = 'error'
  )
ORDER BY p.updated_at DESC
LIMIT 50;

-- Recent sync log failures (PSN/Xbox/Steam)
SELECT 'psn' as platform, user_id, status, sync_type, error_message, created_at
FROM psn_sync_logs
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 50;

SELECT 'xbox' as platform, user_id, status, sync_type, error_message, created_at
FROM xbox_sync_logs
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 50;

SELECT 'steam' as platform, user_id, status, sync_type, error_message, created_at
FROM steam_sync_logs
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 50;
