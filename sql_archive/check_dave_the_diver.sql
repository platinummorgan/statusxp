-- Check DAVE THE DIVER specifically
SELECT 
    platform_game_id,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as null_count,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL) as has_proxied
FROM achievements
WHERE platform_id = 1
  AND platform_game_id = 'NPWR41950_00'
GROUP BY platform_game_id;

-- Show some examples from DAVE THE DIVER
SELECT 
    platform_achievement_id,
    name,
    icon_url,
    proxied_icon_url
FROM achievements
WHERE platform_id = 1
  AND platform_game_id = 'NPWR41950_00'
LIMIT 10;
