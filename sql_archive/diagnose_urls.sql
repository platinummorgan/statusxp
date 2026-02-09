-- URL Diagnostic Report
-- Checks achievement icons, game covers, proxied URLs, and URL handling

-- ============================================
-- ACHIEVEMENT ICON URLs
-- ============================================

-- Count of achievements by URL status
SELECT 
    'Achievement Icon Status' as report_section,
    COUNT(*) FILTER (WHERE icon_url IS NOT NULL) as has_icon_url,
    COUNT(*) FILTER (WHERE icon_url IS NULL) as missing_icon_url,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL) as has_proxied_url,
    COUNT(*) FILTER (WHERE proxied_icon_url IS NULL) as missing_proxied_url,
    COUNT(*) FILTER (WHERE icon_url IS NOT NULL AND proxied_icon_url IS NOT NULL) as has_both,
    COUNT(*) FILTER (WHERE icon_url IS NULL AND proxied_icon_url IS NULL) as has_neither,
    COUNT(*) as total_achievements
FROM achievements;

-- Achievement URL patterns by platform
SELECT 
    p.code as platform,
    COUNT(*) as total_achievements,
    COUNT(*) FILTER (WHERE a.icon_url IS NOT NULL) as has_icon_url,
    COUNT(*) FILTER (WHERE a.proxied_icon_url IS NOT NULL) as has_proxied_url,
    COUNT(*) FILTER (WHERE a.icon_url LIKE '%cloudfront%') as cloudfront_urls,
    COUNT(*) FILTER (WHERE a.icon_url LIKE '%supabase%') as supabase_urls,
    COUNT(*) FILTER (WHERE a.icon_url LIKE '%playstation%' OR a.icon_url LIKE '%psn%') as psn_urls,
    COUNT(*) FILTER (WHERE a.icon_url LIKE '%xbox%') as xbox_urls,
    COUNT(*) FILTER (WHERE a.icon_url LIKE '%steam%') as steam_urls,
    COUNT(*) FILTER (WHERE a.icon_url LIKE 'http://%') as http_urls,
    COUNT(*) FILTER (WHERE a.icon_url LIKE 'https://%') as https_urls
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
GROUP BY p.code
ORDER BY p.code;

-- Sample of different URL patterns
SELECT 
    platform_id,
    platform_game_id,
    name as achievement_name,
    CASE 
        WHEN icon_url LIKE '%cloudfront%' THEN 'CloudFront'
        WHEN icon_url LIKE '%supabase%' THEN 'Supabase'
        WHEN icon_url LIKE '%playstation%' OR icon_url LIKE '%psn%' THEN 'PSN'
        WHEN icon_url LIKE '%xbox%' THEN 'Xbox'
        WHEN icon_url LIKE '%steam%' THEN 'Steam'
        ELSE 'Other'
    END as url_type,
    LEFT(icon_url, 80) as icon_url_sample,
    LEFT(proxied_icon_url, 80) as proxied_url_sample
FROM achievements
WHERE icon_url IS NOT NULL
ORDER BY url_type, platform_id
LIMIT 50;

-- Achievements missing icon URLs (sample)
SELECT 
    p.code as platform,
    a.platform_game_id,
    a.platform_achievement_id,
    a.name as achievement_name,
    g.name as game_name
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
LEFT JOIN games g ON g.platform_id = a.platform_id AND g.platform_game_id = a.platform_game_id
WHERE a.icon_url IS NULL
ORDER BY p.code, g.name
LIMIT 20;

-- ============================================
-- GAME COVER URLs
-- ============================================

-- Game cover URL status
SELECT 
    'Game Cover Status' as report_section,
    COUNT(*) FILTER (WHERE cover_url IS NOT NULL) as has_cover_url,
    COUNT(*) FILTER (WHERE cover_url IS NULL) as missing_cover_url,
    COUNT(*) as total_games
FROM games;

-- Game cover URL patterns by platform
SELECT 
    p.code as platform,
    COUNT(*) as total_games,
    COUNT(*) FILTER (WHERE g.cover_url IS NOT NULL) as has_cover_url,
    COUNT(*) FILTER (WHERE g.cover_url LIKE '%cloudfront%') as cloudfront_urls,
    COUNT(*) FILTER (WHERE g.cover_url LIKE '%supabase%') as supabase_urls,
    COUNT(*) FILTER (WHERE g.cover_url LIKE '%playstation%' OR g.cover_url LIKE '%psn%') as psn_urls,
    COUNT(*) FILTER (WHERE g.cover_url LIKE '%xbox%') as xbox_urls,
    COUNT(*) FILTER (WHERE g.cover_url LIKE '%steam%') as steam_urls,
    COUNT(*) FILTER (WHERE g.cover_url LIKE '%igdb%') as igdb_urls
FROM games g
JOIN platforms p ON p.id = g.platform_id
GROUP BY p.code
ORDER BY p.code;

-- Sample game cover URLs
SELECT 
    p.code as platform,
    g.name as game_name,
    CASE 
        WHEN g.cover_url LIKE '%cloudfront%' THEN 'CloudFront'
        WHEN g.cover_url LIKE '%supabase%' THEN 'Supabase'
        WHEN g.cover_url LIKE '%playstation%' OR g.cover_url LIKE '%psn%' THEN 'PSN'
        WHEN g.cover_url LIKE '%xbox%' THEN 'Xbox'
        WHEN g.cover_url LIKE '%steam%' THEN 'Steam'
        WHEN g.cover_url LIKE '%igdb%' THEN 'IGDB'
        ELSE 'Other'
    END as url_type,
    LEFT(g.cover_url, 100) as cover_url_sample
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.cover_url IS NOT NULL
ORDER BY url_type, p.code
LIMIT 30;

-- Games missing covers (sample)
SELECT 
    p.code as platform,
    g.name as game_name,
    g.platform_game_id,
    COUNT(a.platform_achievement_id) as achievement_count
FROM games g
JOIN platforms p ON p.id = g.platform_id
LEFT JOIN achievements a ON a.platform_id = g.platform_id AND a.platform_game_id = g.platform_game_id
WHERE g.cover_url IS NULL
GROUP BY p.code, g.name, g.platform_game_id
ORDER BY achievement_count DESC, p.code
LIMIT 20;

-- ============================================
-- PROFILE AVATAR URLs
-- ============================================

-- Profile avatar status
SELECT 
    'Profile Avatar Status' as report_section,
    COUNT(*) FILTER (WHERE avatar_url IS NOT NULL) as has_avatar,
    COUNT(*) FILTER (WHERE psn_avatar_url IS NOT NULL) as has_psn_avatar,
    COUNT(*) FILTER (WHERE xbox_avatar_url IS NOT NULL) as has_xbox_avatar,
    COUNT(*) FILTER (WHERE steam_avatar_url IS NOT NULL) as has_steam_avatar,
    COUNT(*) as total_profiles
FROM profiles
WHERE merged_into_user_id IS NULL;

-- ============================================
-- URL CONSISTENCY ISSUES
-- ============================================

-- Achievements with icon_url but missing proxied_icon_url (potential issue)
SELECT 
    COUNT(*) as achievements_need_proxying,
    COUNT(*) FILTER (WHERE icon_url LIKE '%cloudfront%' OR icon_url LIKE '%supabase%') as already_proxied_source
FROM achievements
WHERE icon_url IS NOT NULL 
  AND proxied_icon_url IS NULL;

-- External URLs not yet proxied
SELECT 
    p.code as platform,
    COUNT(*) as external_urls_count
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
WHERE a.icon_url IS NOT NULL 
  AND a.proxied_icon_url IS NULL
  AND a.icon_url NOT LIKE '%cloudfront%'
  AND a.icon_url NOT LIKE '%supabase%'
GROUP BY p.code
ORDER BY external_urls_count DESC;
