-- Check if achievements have NULL proxied_icon_url for a specific game
-- Using DAVE THE DIVER as example (NPWR41950_00)

SELECT 
    platform_id,
    platform_game_id,
    platform_achievement_id,
    name,
    icon_url,
    proxied_icon_url
FROM achievements
WHERE platform_id = 1 -- PSN
  AND platform_game_id = 'NPWR41950_00'
  AND proxied_icon_url IS NULL
  AND icon_url IS NOT NULL
LIMIT 10;

-- Count total missing
SELECT COUNT(*) as missing_proxied_count
FROM achievements
WHERE platform_id = 1 
  AND platform_game_id = 'NPWR41950_00'
  AND proxied_icon_url IS NULL
  AND icon_url IS NOT NULL;
