-- Check how many PSN achievements have NULL proxied_icon_url
SELECT 
    platform_id,
    COUNT(*) as total_achievements,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as null_proxied,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL) as has_proxied
FROM achievements
WHERE platform_id = 1 -- PSN
GROUP BY platform_id;

-- Check specific games
SELECT 
    platform_game_id,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as null_count
FROM achievements
WHERE platform_id = 1
GROUP BY platform_game_id
ORDER BY null_count DESC
LIMIT 10;
