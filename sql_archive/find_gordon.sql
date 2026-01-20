-- Find Gordon's profile with broader search

-- Search for Gordon in profiles (case-insensitive)
SELECT id, display_name, xbox_gamertag, psn_online_id, steam_id
FROM profiles 
WHERE LOWER(display_name) LIKE '%gordon%'
   OR LOWER(xbox_gamertag) LIKE '%gordon%'
   OR LOWER(psn_online_id) LIKE '%gordon%';

-- If that returns nothing, let's see all profiles with Xbox data
SELECT id, display_name, xbox_gamertag, 
  (SELECT COUNT(*) FROM user_games ug 
   JOIN platforms p ON p.id = ug.platform_id 
   WHERE ug.user_id = profiles.id 
   AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) as xbox_game_count
FROM profiles
WHERE xbox_gamertag IS NOT NULL
ORDER BY xbox_game_count DESC
LIMIT 10;
