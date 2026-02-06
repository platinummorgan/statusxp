-- REVERT: Put URLs back to /avatars/achievement-icons/ since that's where files actually are
-- The achievement-icons bucket doesn't exist, files are in avatars bucket subfolder

-- Step 1: Preview the revert
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    proxied_icon_url as current_url,
    REPLACE(proxied_icon_url, '/achievement-icons/', '/avatars/achievement-icons/') as reverted_url
FROM achievements
WHERE proxied_icon_url LIKE '%/achievement-icons/%' 
  AND proxied_icon_url NOT LIKE '%/avatars/%'
LIMIT 10;

-- Step 2: Count how many need to be reverted
SELECT COUNT(*) as records_to_revert
FROM achievements
WHERE proxied_icon_url LIKE '%/achievement-icons/%' 
  AND proxied_icon_url NOT LIKE '%/avatars/%';

-- Step 3: REVERT - Put /avatars/ back in the path
UPDATE achievements
SET proxied_icon_url = REPLACE(proxied_icon_url, '/achievement-icons/', '/avatars/achievement-icons/')
WHERE proxied_icon_url LIKE '%/achievement-icons/%' 
  AND proxied_icon_url NOT LIKE '%/avatars/%';

-- Step 4: Verify the revert
SELECT 
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%') as using_avatars_subfolder,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%' AND proxied_icon_url NOT LIKE '%/avatars/%') as using_root_bucket,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as null_urls
FROM achievements;

-- Step 5: Test URLs are accessible
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    proxied_icon_url
FROM achievements
WHERE proxied_icon_url IS NOT NULL
LIMIT 5;
