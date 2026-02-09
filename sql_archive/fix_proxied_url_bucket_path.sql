-- FIX URGENT: Correct the proxied_icon_url bucket path
-- Current WRONG path: /storage/v1/object/public/avatars/achievement-icons/...
-- Should be: /storage/v1/object/public/achievement-icons/...

-- Step 1: Preview what will be changed (run this first to verify)
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    proxied_icon_url as old_url,
    REPLACE(proxied_icon_url, '/avatars/achievement-icons/', '/achievement-icons/') as new_url
FROM achievements
WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%'
LIMIT 10;

-- Step 2: Count how many will be affected
SELECT COUNT(*) as records_to_fix
FROM achievements
WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%';

-- Step 3: EXECUTE THE FIX - Remove /avatars/ from the path
UPDATE achievements
SET proxied_icon_url = REPLACE(proxied_icon_url, '/avatars/achievement-icons/', '/achievement-icons/')
WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%';

-- Step 4: Verify the fix
SELECT 
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%') as still_wrong,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%' AND proxied_icon_url NOT LIKE '%/avatars/%') as now_correct,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as null_urls
FROM achievements;

-- Step 5: Sample of corrected URLs
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    proxied_icon_url
FROM achievements
WHERE proxied_icon_url IS NOT NULL
LIMIT 10;
