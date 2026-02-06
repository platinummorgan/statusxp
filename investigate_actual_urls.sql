-- Investigate Actual URL Values (Full URLs, not truncated)
-- This will help us understand what went wrong

-- ============================================
-- Check FULL proxied_icon_url values
-- ============================================

-- Sample of proxied URLs that exist
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    icon_url,
    proxied_icon_url
FROM achievements
WHERE proxied_icon_url IS NOT NULL
  AND icon_url LIKE '%supabase%'
LIMIT 10;

-- Check if proxied_icon_url is pointing to wrong storage bucket
SELECT 
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/%') as wrong_bucket_avatars,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%') as correct_bucket,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/game-covers/%') as wrong_bucket_covers,
    COUNT(*) FILTER (WHERE proxied_icon_url NOT LIKE '%/achievement-icons/%' 
                     AND proxied_icon_url NOT LIKE '%/avatars/%'
                     AND proxied_icon_url NOT LIKE '%/game-covers/%') as unknown_path,
    COUNT(*) as total_proxied
FROM achievements
WHERE proxied_icon_url IS NOT NULL;

-- ============================================
-- Check icon_url vs proxied_icon_url mismatch
-- ============================================

-- Achievements where icon_url is already Supabase but proxied_icon_url is different
SELECT 
    platform_id,
    platform_achievement_id,
    name,
    icon_url as supabase_icon_url,
    proxied_icon_url as different_proxied_url
FROM achievements
WHERE icon_url LIKE '%supabase%'
  AND proxied_icon_url IS NOT NULL
  AND icon_url != proxied_icon_url
LIMIT 20;

-- ============================================
-- Platform-specific URL analysis
-- ============================================

-- PS5 achievements - check URL patterns
SELECT 
    'PS5' as platform,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE icon_url LIKE '%psnobj%') as psn_external,
    COUNT(*) FILTER (WHERE icon_url LIKE '%supabase%') as supabase_icon_url,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%supabase%') as supabase_proxied,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%') as correct_path,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/%') as wrong_path
FROM achievements
WHERE platform_id = 1;

-- Steam achievements - check URL patterns
SELECT 
    'Steam' as platform,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE icon_url LIKE '%steamcdn%' OR icon_url LIKE '%steamcommunity%') as steam_external,
    COUNT(*) FILTER (WHERE icon_url LIKE '%supabase%') as supabase_icon_url,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%supabase%') as supabase_proxied,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%') as correct_path
FROM achievements
WHERE platform_id = 4;

-- Xbox achievements - check URL patterns  
SELECT 
    'Xbox One' as platform,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE icon_url LIKE '%xbox%') as xbox_external,
    COUNT(*) FILTER (WHERE icon_url LIKE '%supabase%') as supabase_icon_url,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%supabase%') as supabase_proxied,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%') as correct_path
FROM achievements
WHERE platform_id = 11;
