-- Check YOUR last sync times
SELECT 
  display_name,
  psn_online_id,
  xbox_gamertag,
  last_psn_sync_at,
  last_xbox_sync_at,
  last_steam_sync_at
FROM profiles
WHERE id = auth.uid();

-- Check if ANYONE has achievements (to see if restore wiped everything)
SELECT COUNT(*) as total_achievements_in_database FROM user_achievements;