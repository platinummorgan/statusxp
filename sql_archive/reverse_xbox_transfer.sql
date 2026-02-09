-- Reverse: Move Xbox data BACK to ojjm11@outlook.com
-- FROM: af65c7fb-d1ca-4cad-8f36-a94803ae7930 (oscarmargan20@gmail.com) - temporary account
-- TO: b23e206a-02d1-4920-b1ee-61ee44583518 (ojjm11@outlook.com) - primary account

BEGIN;

DO $$
DECLARE
  temp_user_id UUID := 'af65c7fb-d1ca-4cad-8f36-a94803ae7930';
  primary_user_id UUID := 'b23e206a-02d1-4920-b1ee-61ee44583518';
  xbox_data RECORD;
BEGIN
  -- Get Xbox data from temporary account
  SELECT 
    xbox_xuid,
    xbox_gamertag,
    xbox_user_hash,
    xbox_access_token,
    xbox_refresh_token,
    xbox_token_expires_at,
    xbox_sync_status
  INTO xbox_data
  FROM profiles
  WHERE id = temp_user_id;

  -- Move Xbox data back to primary account
  UPDATE profiles
  SET 
    xbox_xuid = xbox_data.xbox_xuid,
    xbox_gamertag = xbox_data.xbox_gamertag,
    xbox_user_hash = xbox_data.xbox_user_hash,
    xbox_access_token = xbox_data.xbox_access_token,
    xbox_refresh_token = xbox_data.xbox_refresh_token,
    xbox_token_expires_at = xbox_data.xbox_token_expires_at,
    xbox_sync_status = 'error'
  WHERE id = primary_user_id;

  -- Clear Xbox data from temporary account
  UPDATE profiles
  SET 
    xbox_xuid = NULL,
    xbox_gamertag = NULL,
    xbox_user_hash = NULL,
    xbox_access_token = NULL,
    xbox_refresh_token = NULL,
    xbox_token_expires_at = NULL,
    xbox_sync_status = 'never_synced'
  WHERE id = temp_user_id;

  RAISE NOTICE 'Xbox data moved back to primary account %', primary_user_id;
END $$;

COMMIT;

-- Verify
SELECT 
  id,
  (SELECT email FROM auth.users WHERE id = profiles.id) as email,
  xbox_gamertag,
  xbox_xuid,
  xbox_sync_status
FROM profiles
WHERE id IN ('b23e206a-02d1-4920-b1ee-61ee44583518', 'af65c7fb-d1ca-4cad-8f36-a94803ae7930');
