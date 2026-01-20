-- Check TeaTonicDark (jarjarbinks029) account status

-- Profile info
SELECT 
  id,
  username,
  display_name,
  xbox_gamertag,
  xbox_xuid,
  avatar_url,
  xbox_avatar_url,
  xbox_sync_status,
  last_xbox_sync_at,
  preferred_display_platform,
  created_at,
  updated_at
FROM profiles
WHERE username = 'jarjarbinks029';

-- Game count and stats
SELECT 
  COUNT(*) as game_count,
  SUM(statusxp_effective) as total_statusxp,
  SUM(xbox_achievements_earned) as total_achievements,
  SUM(xbox_current_gamerscore) as total_gamerscore
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.username = 'jarjarbinks029';

-- Recent games
SELECT 
  gt.name,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements,
  ug.xbox_current_gamerscore,
  ug.statusxp_effective,
  ug.last_played_at,
  ug.updated_at
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE p.username = 'jarjarbinks029'
ORDER BY ug.updated_at DESC
LIMIT 10;

-- Check leaderboard entry
SELECT 
  rank,
  display_name,
  username,
  statusxp,
  game_count
FROM leaderboard_cache
WHERE username = 'jarjarbinks029';
