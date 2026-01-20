-- Smoke Test Database Validation Queries
-- Run after display_name fixes to verify no issues remain

-- 1. Check for any users with NULL display_name (should be 0)
SELECT 
  id,
  username,
  display_name,
  psn_online_id,
  xbox_gamertag,
  steam_id,
  preferred_platform,
  created_at
FROM profiles
WHERE display_name IS NULL
ORDER BY created_at DESC;

-- 2. Check for users with StatusXP but NULL display_name (critical issue if any found)
SELECT 
  p.id,
  p.username,
  p.display_name,
  COUNT(ug.id) as game_count,
  SUM(COALESCE(ug.statusxp, 0)) as total_statusxp
FROM profiles p
LEFT JOIN user_games ug ON p.id = ug.user_id
WHERE p.display_name IS NULL
GROUP BY p.id, p.username, p.display_name
HAVING SUM(COALESCE(ug.statusxp, 0)) > 0;

-- 3. Verify leaderboard top 50 - all should have display names
SELECT 
  rank,
  display_name,
  username,
  statusxp,
  game_count
FROM leaderboard_cache
WHERE rank <= 50
ORDER BY rank;

-- 4. Check spawns_shadow status (should have 0 games now)
SELECT 
  p.id,
  p.username,
  p.display_name,
  p.psn_online_id,
  p.psn_account_id,
  COUNT(ug.id) as game_count
FROM profiles p
LEFT JOIN user_games ug ON p.id = ug.user_id
WHERE p.username = 'spawns_shadow'
GROUP BY p.id, p.username, p.display_name, p.psn_online_id, p.psn_account_id;

-- 5. Verify Jasoness (should show as "Jasonness")
SELECT 
  username,
  display_name,
  psn_online_id,
  preferred_platform,
  statusxp,
  rank
FROM leaderboard_cache
WHERE username = 'jgmartinez24';

-- 6. Verify TeaTonicDark
SELECT 
  username,
  display_name,
  xbox_gamertag,
  preferred_platform,
  statusxp,
  rank
FROM leaderboard_cache
WHERE username = 'jarjarbinks029';

-- 7. Check for any orphaned games (games without valid user)
SELECT 
  ug.user_id,
  COUNT(*) as orphaned_games
FROM user_games ug
LEFT JOIN profiles p ON ug.user_id = p.id
WHERE p.id IS NULL
GROUP BY ug.user_id;

-- 8. Verify recent syncs completed successfully
SELECT 
  user_id,
  status,
  total_trophies_synced,
  started_at,
  completed_at,
  error_message
FROM psn_sync_logs
WHERE started_at > NOW() - INTERVAL '24 hours'
ORDER BY started_at DESC
LIMIT 10;
