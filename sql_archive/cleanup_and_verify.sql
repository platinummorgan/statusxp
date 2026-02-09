-- Clean up orphaned profile and verify main account
BEGIN;

-- Delete profile for the deleted Gmail account (if it still exists)
DELETE FROM profiles 
WHERE id = 'af65c7fb-d1ca-4cad-8f36-a94803ae7930';

-- Verify main account is ready
SELECT 
  au.id,
  au.email,
  p.display_name,
  p.xbox_xuid,
  p.xbox_gamertag,
  p.psn_online_id,
  p.steam_id,
  p.xbox_sync_status,
  p.psn_sync_status,
  p.steam_sync_status
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
WHERE au.email = 'ojjm11@outlook.com';

COMMIT;
