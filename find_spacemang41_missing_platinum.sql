-- Find DaHead22's missing platinums (should have 8, we have 6)

-- Step 1: Find DaHead22's profile and current platinum count
SELECT 
  id,
  psn_online_id,
  (SELECT COUNT(*) FROM user_games WHERE user_id = profiles.id AND platinum_trophies > 0 AND platform_id = 1) as our_platinum_count
FROM profiles
WHERE psn_online_id = 'DaHead22';

-- Step 2: Find all games where DaHead22 has 100% completion but no platinum recorded
SELECT 
  gt.name as game_name,
  ug.completion_percent,
  ug.earned_trophies,
  ug.total_trophies,
  ug.platinum_trophies,
  ug.has_platinum,
  ug.last_played_at,
  ug.sync_failed,
  ug.sync_error
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1  -- PSN
  AND ug.completion_percent = 100
  AND (ug.platinum_trophies = 0 OR ug.platinum_trophies IS NULL)
ORDER BY ug.last_played_at DESC NULLS LAST;

-- Step 3: Check for games with sync failures
SELECT 
  gt.name as game_name,
  ug.sync_failed,
  ug.sync_error,
  ug.last_sync_attempt,
  ug.completion_percent,
  ug.platinum_trophies
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
  AND ug.sync_failed = true
ORDER BY ug.last_sync_attempt DESC;

-- Step 4: List all DaHead22's platinum games we DO have (should be 6)
SELECT 
  gt.name as game_name,
  gt.psn_npwr_id,
  ug.completion_percent,
  ug.platinum_trophies,
  ug.earned_trophies,
  ug.total_trophies,
  ug.last_played_at
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
  AND ug.platinum_trophies > 0
ORDER BY ug.last_played_at DESC NULLS LAST;
