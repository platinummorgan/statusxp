-- Check Dexmorgan6981's sync status
SELECT 
  p.xbox_gamertag,
  p.xbox_sync_status,
  p.xbox_sync_progress,
  xsl.id as log_id,
  xsl.status,
  xsl.games_processed,
  xsl.games_total,
  xsl.error_message,
  xsl.started_at,
  NOW() - xsl.started_at as running_time
FROM profiles p
LEFT JOIN xbox_sync_logs xsl ON xsl.user_id = p.id
WHERE p.id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY xsl.started_at DESC
LIMIT 1;

-- Check if any games failing sync
SELECT 
  gt.name,
  ug.sync_error,
  ug.last_sync_attempt
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.sync_failed = true
ORDER BY ug.last_sync_attempt DESC
LIMIT 5;
