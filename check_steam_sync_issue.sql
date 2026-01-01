-- Check SternalJet's achievement platform breakdown
SELECT 
    a.platform,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as game_count
FROM profiles p
INNER JOIN user_achievements ua ON ua.user_id = p.id
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE p.steam_display_name = 'SternalJet'
GROUP BY a.platform
ORDER BY achievement_count DESC;

-- Check if Steam games exist but achievements weren't synced
SELECT 
    'Steam games in user_games:' as info,
    COUNT(*) as steam_games
FROM profiles p
INNER JOIN user_games ug ON ug.user_id = p.id
INNER JOIN platforms pl ON pl.id = ug.platform_id
WHERE p.steam_display_name = 'SternalJet'
    AND pl.code = 'Steam';

-- Check if there are ANY steam platform achievements in the achievements table for SternalJet's games
SELECT 
    'Steam achievements in achievements table for SternalJet games:' as info,
    COUNT(*) as steam_achievement_definitions
FROM achievements a
INNER JOIN user_games ug ON ug.game_title_id = a.game_title_id
INNER JOIN profiles p ON p.id = ug.user_id
INNER JOIN platforms pl ON pl.id = ug.platform_id
WHERE p.steam_display_name = 'SternalJet'
    AND pl.code = 'Steam'
    AND a.platform = 'steam';
