-- Debug Steam Leaderboard Issues
-- Run this to find out why Steam users aren't showing on leaderboard

-- 1. Check if there are Steam users with achievements
SELECT 
    p.id,
    p.steam_id,
    p.steam_display_name,
    p.show_on_leaderboard,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as games_count
FROM profiles p
INNER JOIN user_achievements ua ON ua.user_id = p.id
INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
WHERE p.steam_id IS NOT NULL
GROUP BY p.id, p.steam_id, p.steam_display_name, p.show_on_leaderboard
ORDER BY achievement_count DESC;

-- 2. Check Steam leaderboard cache contents
SELECT * FROM steam_leaderboard_cache ORDER BY achievement_count DESC;

-- 3. Check if there are users with Steam games but no achievements synced yet
SELECT 
    p.id,
    p.steam_id,
    p.steam_display_name,
    ug.game_title_id,
    ug.earned_trophies,
    ug.total_trophies
FROM profiles p
INNER JOIN user_games ug ON ug.user_id = p.id
INNER JOIN platforms pl ON pl.id = ug.platform_id AND pl.code = 'Steam'
WHERE p.steam_id IS NOT NULL
    AND ug.earned_trophies > 0
ORDER BY p.id, ug.earned_trophies DESC;

-- 4. If users exist but cache is empty, manually refresh it
SELECT refresh_steam_leaderboard_cache();

-- 5. Verify cache was populated
SELECT COUNT(*) as total_entries FROM steam_leaderboard_cache;
