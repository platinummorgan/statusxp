-- Check Death Stranding 2 achievement proxy status after sync
SELECT 
    platform_achievement_id,
    title,
    CASE 
        WHEN icon_url LIKE '%supabase%' THEN 'CORRUPTED (Supabase in icon_url)'
        WHEN icon_url LIKE '%image.api.playstation.com%' THEN 'External PSN URL'
        WHEN icon_url LIKE '%psnobj.prod.dl.playstation.net%' THEN 'External PSN CDN'
        ELSE 'Other: ' || LEFT(icon_url, 50)
    END as icon_url_status,
    CASE 
        WHEN proxied_icon_url IS NOT NULL THEN 'HAS PROXY'
        ELSE 'NO PROXY'
    END as proxy_status,
    LEFT(icon_url, 80) as icon_url_preview,
    LEFT(proxied_icon_url, 80) as proxied_url_preview
FROM achievements
WHERE platform_id = 2 -- PS4
  AND platform_game_id = 'CUSA29397_00'
ORDER BY platform_achievement_id
LIMIT 10;
