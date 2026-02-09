-- Check user's PSN token status
SELECT 
  p.id,
  au.email,
  p.psn_online_id,
  p.psn_token_expires_at,
  p.psn_token_expires_at < NOW() as token_expired,
  p.psn_sync_status
FROM profiles p
JOIN auth.users au ON au.id = p.id
WHERE p.id = 'b23e206a-02d1-4920-b1ee-61ee44583518';
