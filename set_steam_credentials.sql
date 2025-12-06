-- Update your profile with Steam credentials
-- Replace YOUR_USER_ID with your actual Supabase user ID

UPDATE profiles
SET 
  steam_id = '76561198025758586',
  steam_api_key = 'D60D536DC10F3158F9BB910EDFB17423'
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Verify it was set
SELECT id, steam_id, steam_api_key, steam_sync_status 
FROM profiles 
WHERE steam_id IS NOT NULL;
