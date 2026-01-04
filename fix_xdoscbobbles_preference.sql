-- Fix xdoscbobbles showing as "Unknown" by setting preferred platform to Xbox
-- This user only has Xbox gamertag, not PSN

UPDATE profiles
SET preferred_display_platform = 'xbox'
WHERE id = 'c5ff31aa-8572-441a-ab09-22accd4c979b';

-- Verify the fix
SELECT 
  id,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  preferred_display_platform
FROM profiles
WHERE id = 'c5ff31aa-8572-441a-ab09-22accd4c979b';
