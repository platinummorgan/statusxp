-- URGENT: Check if proxied_icon_url is pointing to wrong storage bucket
-- This will tell us if URLs are going to /avatars/ instead of /achievement-icons/

-- Query 1: Count URLs by storage bucket path
SELECT 
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/%') as wrong_bucket_avatars,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%') as correct_bucket,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL AND proxied_icon_url NOT LIKE '%/avatars/%' AND proxied_icon_url NOT LIKE '%/achievement-icons/%') as other_bucket,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as null_proxied,
    COUNT(*) as total_achievements
FROM achievements;

-- Query 2: Sample of FULL proxied_icon_url values (not truncated)
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    LENGTH(proxied_icon_url) as url_length,
    proxied_icon_url as full_proxied_url
FROM achievements
WHERE proxied_icon_url IS NOT NULL
LIMIT 20;

-- Query 3: Check for mismatches - Supabase URL in icon_url but different/missing in proxied_icon_url
SELECT 
    COUNT(*) as mismatch_count,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as proxied_is_null,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL AND icon_url != proxied_icon_url) as urls_different
FROM achievements
WHERE icon_url LIKE '%supabase%';

-- Query 4: Sample of mismatched records
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    icon_url,
    proxied_icon_url
FROM achievements
WHERE icon_url LIKE '%supabase%' AND proxied_icon_url IS NULL
LIMIT 10;

-- Query 5: Check platform-specific URL patterns
SELECT 
    p.name as platform,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/%') as using_avatars_bucket,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%') as using_achievement_icons_bucket,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as no_proxied_url
FROM achievements a
JOIN platforms p ON a.platform_id = p.id
WHERE p.name IN ('PS5', 'PS4', 'Steam', 'XboxSeriesX')
GROUP BY p.name
ORDER BY p.name;

-- Query 6: Find exact URL patterns in proxied_icon_url
SELECT 
    SUBSTRING(proxied_icon_url FROM 1 FOR 100) as url_prefix_pattern,
    COUNT(*) as count
FROM achievements
WHERE proxied_icon_url IS NOT NULL
GROUP BY SUBSTRING(proxied_icon_url FROM 1 FOR 100)
ORDER BY count DESC
LIMIT 10;
