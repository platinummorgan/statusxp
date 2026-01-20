-- Debug: Why isn't SternalJet's data being picked up by the refresh function?

-- Check if achievements exist but aren't being joined properly
SELECT 
    'SternalJet achievements in user_achievements:' as info,
    COUNT(DISTINCT ua.id) as user_achievement_records
FROM profiles p
INNER JOIN user_achievements ua ON ua.user_id = p.id
WHERE p.steam_display_name = 'SternalJet';

-- Check if they're linked to achievements table with platform='steam'
SELECT 
    'SternalJet achievements linked to achievements table (platform=steam):' as info,
    COUNT(DISTINCT ua.id) as count
FROM profiles p
INNER JOIN user_achievements ua ON ua.user_id = p.id
INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
WHERE p.steam_display_name = 'SternalJet';

-- Check raw achievements for this user (any platform)
SELECT 
    'SternalJet raw achievement breakdown:' as info,
    a.platform,
    COUNT(*) as count
FROM profiles p
INNER JOIN user_achievements ua ON ua.user_id = p.id
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE p.steam_display_name = 'SternalJet'
GROUP BY a.platform;

-- Show sample of SternalJet's achievements
SELECT 
    'Sample of SternalJet achievements:' as info,
    a.platform,
    a.name,
    a.game_title_id,
    gt.name as game_name
FROM profiles p
INNER JOIN user_achievements ua ON ua.user_id = p.id
INNER JOIN achievements a ON a.id = ua.achievement_id
LEFT JOIN game_titles gt ON gt.id = a.game_title_id
WHERE p.steam_display_name = 'SternalJet'
LIMIT 10;
