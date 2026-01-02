-- Audit platinum trophies for a user
-- PSN ID: Dex-Morgan

-- Option 1: Count platinums by platform
SELECT 
  'PlayStation' as platform,
  COUNT(*) as platinum_count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND a.is_platinum = true;

-- Option 2: List all your platinums with game names
SELECT 
  g.name as game_name,
  a.name as trophy_name,
  ua.created_at
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles g ON a.game_title_id = g.id
WHERE ua.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND a.is_platinum = true
ORDER BY ua.created_at DESC NULLS LAST;

-- Option 3: Find games with 100% completion but no platinum
SELECT 
  g.name as game_name,
  COUNT(*) as total_trophies,
  SUM(CASE WHEN a.unlocked THEN 1 ELSE 0 END) as unlocked_trophies,
  ROUND(100.0 * SUM(CASE WHEN a.unlocked THEN 1 ELSE 0 END) / COUNT(*), 2) as completion_pct
FROM achievements a
JOIN game_titles g ON a.game_title_id = g.id
WHERE a.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
GROUP BY g.id, g.name, p.name
HAVING 
  SUM(CASE WHEN a.unlocked THEN 1 ELSE 0 END) = COUNT(*) -- 100% complete
  AND COUNT(*) > 0
  AND NOT EXISTS ( -- but no platinum unlocked
    SELECT 1 FROM achievements a2 
    WHERE a2.game_title_id = g.id 
      AND a2.user_id = a.user_id
      AND a2.is_platinum = true 
      AND a2.unlocked = true
  )
ORDER BY g.name;

-- Option 4: Check PSN sync logs for errors that might have lost data
SELECT 
  created_at,
  status,
  games_processed,
  trophies_synced,
  error_message
FROM psn_sync_logs
WHERE user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
ORDER BY created_at DESC
LIMIT 10;

-- Option 5: Find your current total platinum count
SELECT 
  psn_online_id,
  (SELECT COUNT(*) 
   FROM user_achievements ua2
   JOIN achievements a2 ON ua2.achievement_id = a2.id
   WHERE ua2.user_id = profiles.id 
     AND a2.is_platinum = true
  ) as platinum_count
FROM profiles
WHERE psn_online_id = 'Dex-Morgan';
