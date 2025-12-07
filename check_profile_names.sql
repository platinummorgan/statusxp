-- Check current Xbox and Steam profile data
SELECT 
  id,
  xbox_xuid,
  xbox_gamertag,
  steam_id,
  steam_display_name
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
