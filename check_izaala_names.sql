-- Check what usernames exist for the user who gained 9391 StatusXP
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  p.preferred_display_platform,
  lc.total_statusxp,
  lc.display_name as leaderboard_display_name
FROM profiles p
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.username ILIKE '%Izaala%'
  OR p.psn_online_id ILIKE '%Izaala%'
  OR p.xbox_gamertag ILIKE '%Izaala%'
  OR p.steam_display_name ILIKE '%Izaala%'
  OR lc.display_name ILIKE '%Izaala%';

-- Also check the actual activity feed entry
SELECT 
  user_id,
  username,
  story_text,
  event_type,
  created_at
FROM activity_feed
WHERE story_text ILIKE '%Izaala%'
ORDER BY created_at DESC
LIMIT 1;
