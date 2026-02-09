-- Fix URL Issues
-- This addresses the data integrity problems found in the diagnostic

-- ============================================
-- ISSUE 1: Supabase URLs in icon_url but missing proxied_icon_url
-- ============================================
-- These 49,794 achievements already have Supabase storage URLs in icon_url
-- but the proxied_icon_url column is NULL. This is a data integrity issue.
-- Copy icon_url to proxied_icon_url for these records.

UPDATE achievements
SET proxied_icon_url = icon_url
WHERE icon_url LIKE '%supabase%'
  AND proxied_icon_url IS NULL;

-- Expected: ~49,794 rows updated

-- ============================================
-- VERIFICATION: Check the fix worked
-- ============================================

SELECT 
    'After Fix - Achievement Icon Status' as report_section,
    COUNT(*) FILTER (WHERE icon_url IS NOT NULL) as has_icon_url,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL) as has_proxied_url,
    COUNT(*) FILTER (WHERE icon_url IS NOT NULL AND proxied_icon_url IS NULL) as still_need_proxying,
    COUNT(*) as total_achievements
FROM achievements;

-- Remaining external URLs that need proxying (excludes Xbox since no CORS issues)
SELECT 
    p.code as platform,
    COUNT(*) as external_urls_needing_proxy
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
WHERE a.icon_url IS NOT NULL 
  AND a.proxied_icon_url IS NULL
  AND a.icon_url NOT LIKE '%cloudfront%'
  AND a.icon_url NOT LIKE '%supabase%'
  AND p.code IN ('Steam', 'PS5', 'PS4', 'PS3', 'PSVITA')  -- Only platforms with CORS issues
GROUP BY p.code
ORDER BY external_urls_needing_proxy DESC;
