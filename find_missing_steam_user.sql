-- Find the new Steam user who isn't showing up
-- This will show EXACTLY why they're blocked

SELECT 
    p.steam_id,
    p.steam_display_name,
    p.show_on_leaderboard,
    COUNT(DISTINCT ua.id) as steam_achievement_count,
    COUNT(DISTINCT ug.id) as steam_games_count,
    CASE 
        WHEN p.show_on_leaderboard = false THEN '🚫 FIX: Set show_on_leaderboard = true'
        WHEN COUNT(DISTINCT ua.id) = 0 THEN '⚠️ No achievements in user_achievements table yet'
        WHEN p.steam_display_name IS NULL THEN '⚠️ No display name - sync might have failed'
        ELSE '✅ Should be visible after cache refresh'
    END as issue
FROM profiles p
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN platforms pl ON pl.id = ug.platform_id AND pl.code = 'Steam'
WHERE p.steam_id IS NOT NULL
    AND p.id NOT IN (SELECT user_id FROM steam_leaderboard_cache)
GROUP BY p.id, p.steam_id, p.steam_display_name, p.show_on_leaderboard
ORDER BY steam_achievement_count DESC;
