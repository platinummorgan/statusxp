-- Find Robo Ripper by different methods
SELECT 
  id,
  username,
  display_name,
  xbox_gamertag,
  psn_online_id,
  steam_display_name
FROM profiles
WHERE username ILIKE '%robo%'
   OR display_name ILIKE '%robo%'
   OR xbox_gamertag ILIKE '%robo%'
   OR psn_online_id ILIKE '%robo%'
   OR steam_display_name ILIKE '%robo%';

-- Check if there's a user_games table (old schema)
SELECT COUNT(*) as count_in_user_games
FROM user_games
WHERE user_id = (SELECT id FROM profiles WHERE username ILIKE '%robo%' LIMIT 1);

-- List all tables to see what exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
  AND table_name LIKE '%user%'
ORDER BY table_name;
