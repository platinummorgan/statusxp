-- Check Xbox credentials and token expiry
SELECT 
  id,
  xbox_gamertag,
  xbox_xuid,
  xbox_token_expires_at,
  CASE 
    WHEN xbox_token_expires_at IS NULL THEN 'No expiry set'
    WHEN xbox_token_expires_at < NOW() THEN 'EXPIRED'
    ELSE 'Valid'
  END as token_status,
  CASE 
    WHEN xbox_token_expires_at IS NOT NULL THEN 
      EXTRACT(EPOCH FROM (xbox_token_expires_at - NOW())) / 3600
    ELSE NULL
  END as hours_until_expiry,
  xbox_access_token IS NOT NULL as has_access_token,
  xbox_refresh_token IS NOT NULL as has_refresh_token,
  xbox_user_hash IS NOT NULL as has_user_hash,
  xbox_sync_status,
  last_xbox_sync_at
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
