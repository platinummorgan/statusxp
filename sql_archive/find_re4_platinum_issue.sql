-- Find what happened to RE4 platinum during resyncs

-- Check 1: Does the RE4 platinum achievement exist at all in achievements table?
SELECT 
  a.id as achievement_id,
  a.name as trophy_name,
  a.is_platinum,
  a.game_title_id,
  a.psn_trophy_id,
  a.created_at
FROM achievements a
WHERE a.game_title_id = 233  -- RE4 game_title_id from your query
  AND a.is_platinum = true;

-- Check 2: Show ALL achievements for RE4 (not just unlocked ones)
SELECT 
  a.id as achievement_id,
  a.name as trophy_name,
  a.is_platinum,
  a.trophy_type,
  a.psn_trophy_id,
  a.created_at
FROM achievements a
WHERE a.game_title_id = 233
ORDER BY a.is_platinum DESC, a.trophy_type;

-- Check 3: Check if there's a platinum with a different is_platinum value
SELECT 
  a.id as achievement_id,
  a.name as trophy_name,
  a.trophy_type,
  a.is_platinum,
  a.psn_trophy_id
FROM achievements a
WHERE a.game_title_id = 233
  AND (a.name ILIKE '%platinum%' OR a.trophy_type = 'platinum');

-- Check 4: Check for duplicate RE4 game titles
SELECT 
  g.id,
  g.name,
  g.psn_title_id,
  g.created_at,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = g.id) as achievement_count
FROM game_titles g
WHERE g.name ILIKE '%resident evil 4%'
ORDER BY g.created_at;

-- Check 5: Find ANY platinum achievements that might be orphaned from RE4
SELECT 
  a.id,
  a.name,
  a.game_title_id,
  a.psn_trophy_id,
  g.name as game_name
FROM achievements a
LEFT JOIN game_titles g ON a.game_title_id = g.id
WHERE a.is_platinum = true
  AND (a.name ILIKE '%resident evil%' OR g.name ILIKE '%resident evil 4%')
ORDER BY a.created_at DESC;
