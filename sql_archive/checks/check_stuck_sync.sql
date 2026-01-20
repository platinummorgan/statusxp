-- Check what's happening with X_imThumper_X's sync
SELECT 
  p.xbox_gamertag,
  p.xbox_sync_status,
  p.xbox_sync_progress,
  xsl.id as log_id,
  xsl.status as log_status,
  xsl.games_processed,
  xsl.games_total,
  xsl.error_message,
  xsl.started_at,
  NOW() - xsl.started_at as running_time
FROM profiles p
LEFT JOIN xbox_sync_logs xsl ON xsl.user_id = p.id
WHERE p.id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
ORDER BY xsl.started_at DESC
LIMIT 1;

-- Check if any games have sync_failed flag
SELECT 
  gt.name,
  ug.sync_error,
  ug.last_sync_attempt
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND ug.sync_failed = true
ORDER BY ug.last_sync_attempt DESC
LIMIT 10;
