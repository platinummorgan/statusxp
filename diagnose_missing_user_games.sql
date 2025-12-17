-- Check if games exist but aren't in user_games

-- 1. How many total PSN game_titles exist in database?
SELECT COUNT(*) as total_psn_games
FROM game_titles gt
WHERE EXISTS (
  SELECT 1 FROM achievements a 
  WHERE a.game_title_id = gt.id 
    AND a.platform = 'psn'
);

-- 2. How many of those have YOUR user_achievements?
SELECT COUNT(DISTINCT gt.id) as games_you_have_trophies_for
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = (SELECT id FROM profiles LIMIT 1)
  AND a.platform = 'psn';

-- 3. Check your last PSN sync status
SELECT 
  psn_sync_status,
  psn_sync_progress,
  last_psn_sync_at,
  psn_sync_error
FROM profiles
WHERE id = (SELECT id FROM profiles LIMIT 1);

-- 4. Check the latest PSN sync log
SELECT 
  id,
  status,
  games_processed,
  trophies_synced,
  started_at,
  completed_at,
  error_message
FROM psn_sync_logs
WHERE user_id = (SELECT id FROM profiles LIMIT 1)
ORDER BY started_at DESC
LIMIT 3;

-- 5. List what SHOULD be in user_games but isn't
SELECT 
  gt.name,
  COUNT(DISTINCT a.id) as total_trophies_in_db,
  COUNT(DISTINCT ua.id) as trophies_you_earned
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = (SELECT id FROM profiles LIMIT 1)
  AND a.platform = 'psn'
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug
    WHERE ug.game_title_id = gt.id
      AND ug.user_id = (SELECT id FROM profiles LIMIT 1)
  )
GROUP BY gt.name
ORDER BY trophies_you_earned DESC;
