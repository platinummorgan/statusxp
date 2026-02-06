-- Cleanup: Remove proxied URLs that point to wrong numbered folders (1, 2, 5, etc.)
-- These were created by the buggy backfill function using platform_id instead of platform code

-- Step 1: Find URLs pointing to numbered folders
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    proxied_icon_url
FROM achievements
WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/1/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/2/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/3/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/4/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/5/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/6/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/7/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/8/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/9/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/10/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/11/%'
   OR proxied_icon_url LIKE '%/avatars/achievement-icons/12/%'
LIMIT 10;

-- Step 2: Count how many need cleanup
SELECT COUNT(*) as wrong_numbered_folders
FROM achievements
WHERE proxied_icon_url SIMILAR TO '%/avatars/achievement-icons/[0-9]+/%';

-- Step 3: NULL out these wrong URLs (they point to files in wrong folder structure)
UPDATE achievements
SET proxied_icon_url = NULL
WHERE proxied_icon_url SIMILAR TO '%/avatars/achievement-icons/[0-9]+/%';

-- Step 4: Verify cleanup
SELECT 
    COUNT(*) FILTER (WHERE proxied_icon_url SIMILAR TO '%/avatars/achievement-icons/[0-9]+/%') as still_numbered,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/psn/%') as psn_folder,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/xbox/%') as xbox_folder,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/steam/%') as steam_folder,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as null_urls
FROM achievements;

-- Step 5: Check icon_url is still intact
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    icon_url,
    proxied_icon_url
FROM achievements
WHERE icon_url IS NOT NULL
LIMIT 10;
