-- Check sync logs for recent Xbox sync attempts
SELECT 
  id,
  user_id,
  platform,
  status,
  error_message,
  started_at,
  completed_at,
  games_synced,
  achievements_synced
FROM sync_logs
WHERE platform = 'xbox'
ORDER BY started_at DESC
LIMIT 10;

-- Check profile Xbox connection status
SELECT 
  id,
  display_name,
  xbox_gamertag,
  xbox_xuid,
  CASE WHEN xbox_access_token IS NOT NULL THEN LENGTH(xbox_access_token) ELSE 0 END as token_length,
  CASE WHEN xbox_refresh_token IS NOT NULL THEN LENGTH(xbox_refresh_token) ELSE 0 END as refresh_token_length,
  CASE WHEN xbox_user_hash IS NOT NULL THEN LENGTH(xbox_user_hash) ELSE 0 END as hash_length,
  last_xbox_sync,
  updated_at
FROM profiles
WHERE xbox_gamertag IS NOT NULL;
