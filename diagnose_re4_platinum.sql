-- Diagnose RE4 Platinum Trophy Issue
-- User had this platinum before, now it's missing after resyncs

-- Check 1: Does RE4 exist in user_games?
SELECT 
  ug.id as user_game_id,
  g.id as game_title_id,
  g.name as game_name,
  ug.completion_percent,
  ug.earned_trophies,
  ug.total_trophies
FROM user_games ug
JOIN game_titles g ON ug.game_title_id = g.id
WHERE ug.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND g.name ILIKE '%resident evil 4%';

-- Check 2: Find ALL game titles with "resident evil 4" (check for duplicates)
SELECT 
  id,
  name,
  psn_platform,
  created_at
FROM game_titles
WHERE name ILIKE '%resident evil 4%'
ORDER BY created_at;

-- Check 3: Does RE4 have a platinum achievement defined?
SELECT 
  a.id as achievement_id,
  a.name as trophy_name,
  a.is_platinum,
  a.game_title_id,
  g.name as game_name
FROM achievements a
JOIN game_titles g ON a.game_title_id = g.id
WHERE g.name ILIKE '%resident evil 4%'
  AND a.is_platinum = true;

-- Check 4: Is there a user_achievement entry for Dex-Morgan + RE4 platinum?
SELECT 
  ua.id as user_achievement_id,
  ua.user_id,
  ua.achievement_id,
  ua.created_at,
  a.name as trophy_name,
  a.is_platinum,
  g.name as game_name
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles g ON a.game_title_id = g.id
WHERE ua.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND g.name ILIKE '%resident evil 4%'
  AND a.is_platinum = true;

-- Check 5: Show ALL RE4 achievements for this user (to see if ANY trophies are linked)
SELECT 
  g.name as game_name,
  a.name as trophy_name,
  a.is_platinum,
  ua.created_at as unlocked_at
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles g ON a.game_title_id = g.id
WHERE ua.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND g.name ILIKE '%resident evil 4%'
ORDER BY a.is_platinum DESC, ua.created_at;

-- Check 6: Look for orphaned platinum achievements (platinum with no game link)
SELECT 
  a.id,
  a.name,
  a.game_title_id,
  a.is_platinum
FROM achievements a
LEFT JOIN game_titles g ON a.game_title_id = g.id
WHERE a.is_platinum = true
  AND a.game_title_id IN (
    SELECT id FROM game_titles WHERE name ILIKE '%resident evil 4%'
  );
