-- Check achievements table for DLC/group columns
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'achievements' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Sample achievements from AC Odyssey to see structure
SELECT id, name, description
FROM achievements
WHERE game_title_id = 171
  AND platform = 'psn'
ORDER BY id
LIMIT 10;
