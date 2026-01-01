-- Quick diagnosis: Why aren't Steam users showing in leaderboard?

-- Check ALL Steam users and their status
SELECT 
    p.id,
    p.steam_id,
    p.steam_display_name,
    p.show_on_leaderboard,
    p.display_name,
    CASE 
        WHEN p.steam_id IS NULL THEN '❌ No Steam ID'
        WHEN p.show_on_leaderboard = false THEN '❌ Hidden from leaderboard (show_on_leaderboard=false)'
        WHEN p.steam_display_name IS NULL AND p.display_name IS NULL THEN '❌ No display name'
        ELSE '✅ Should appear'
    END as status,
    (SELECT COUNT(*) FROM user_achievements ua 
     INNER JOIN achievements a ON a.id = ua.achievement_id 
     WHERE ua.user_id = p.id AND a.platform = 'steam') as steam_achievements
FROM profiles p
WHERE p.steam_id IS NOT NULL
ORDER BY steam_achievements DESC;

-- Show who IS in the cache
SELECT 
    '✅ Currently in Steam leaderboard cache:' as info,
    display_name,
    achievement_count
FROM steam_leaderboard_cache
ORDER BY achievement_count DESC;
