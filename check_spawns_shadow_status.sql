-- Check spawns_shadow current status after fixes

-- Profile info
SELECT 
  id,
  username,
  display_name,
  psn_online_id,
  psn_account_id,
  avatar_url,
  psn_avatar_url,
  psn_sync_status,
  last_psn_sync_at,
  created_at,
  updated_at
FROM profiles
WHERE username = 'spawns_shadow';

-- Game count
SELECT 
  COUNT(*) as game_count,
  SUM(statusxp_effective) as total_statusxp
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.username = 'spawns_shadow';

-- Recent games (if any)
SELECT 
  gt.name,
  ug.earned_trophies,
  ug.total_trophies,
  ug.statusxp_effective,
  ug.last_played_at,
  ug.created_at,
  ug.updated_at
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE p.username = 'spawns_shadow'
ORDER BY ug.updated_at DESC
LIMIT 10;
