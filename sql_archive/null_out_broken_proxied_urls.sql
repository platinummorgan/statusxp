-- EMERGENCY FIX: NULL out proxied_icon_url since files don't exist in Storage
-- This will make apps fall back to using icon_url (direct external URLs)

-- Step 1: Preview what will be affected
SELECT 
    COUNT(*) as total_proxied_urls,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%') as avatars_subfolder,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%supabase%') as all_supabase_urls
FROM achievements
WHERE proxied_icon_url IS NOT NULL;

-- Step 2: NULL them out since files don't exist in Storage anyway
UPDATE achievements
SET proxied_icon_url = NULL
WHERE proxied_icon_url IS NOT NULL;

-- Step 3: Verify all proxied URLs are now NULL
SELECT 
    COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL) as still_have_proxied,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as now_null,
    COUNT(*) as total
FROM achievements;

-- Step 4: Check icon_url values are still intact
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    icon_url,
    proxied_icon_url
FROM achievements
WHERE icon_url IS NOT NULL
LIMIT 10;
