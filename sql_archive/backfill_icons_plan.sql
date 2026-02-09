-- Backfill Plan for Remaining Achievement Icons
-- After running fix_achievement_urls.sql, use this to backfill the remaining external URLs

-- Priority 1: Steam (6,962 achievements) - CORS issues on web
-- Priority 2: PS5 (11 achievements) - Quick win
-- Priority 3: PS Vita (1 achievement) - Trivial
-- Skip: Xbox One (6,069) - No CORS issues, can wait

-- ============================================
-- Get Steam achievements needing proxy
-- ============================================
SELECT 
    platform_id,
    platform_game_id,
    platform_achievement_id,
    name,
    icon_url
FROM achievements
WHERE platform_id = 4  -- Steam
  AND icon_url IS NOT NULL
  AND proxied_icon_url IS NULL
  AND icon_url NOT LIKE '%supabase%'
ORDER BY platform_game_id, platform_achievement_id
LIMIT 100;

-- Count by game to prioritize high-value games
SELECT 
    g.name as game_name,
    a.platform_game_id,
    COUNT(*) as icons_to_proxy
FROM achievements a
JOIN games g ON g.platform_id = a.platform_id AND g.platform_game_id = a.platform_game_id
WHERE a.platform_id = 4  -- Steam
  AND a.icon_url IS NOT NULL
  AND a.proxied_icon_url IS NULL
  AND a.icon_url NOT LIKE '%supabase%'
GROUP BY g.name, a.platform_game_id
ORDER BY icons_to_proxy DESC
LIMIT 20;

-- ============================================
-- Backfill Edge Function Call Template
-- ============================================
-- Use the existing backfill-achievement-icons Edge Function
-- Call it with these parameters:

/*
POST https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/backfill-achievement-icons

Headers:
- Authorization: Bearer {SUPABASE_ANON_KEY}
- apikey: {SUPABASE_ANON_KEY}
- Content-Type: application/json

Body:
{
  "platform_ids": [4],  // Steam only first
  "batch_size": 100,
  "offset": 0
}

Then increment offset by 100 for each batch:
- offset: 0 (achievements 1-100)
- offset: 100 (achievements 101-200)
- offset: 200 (achievements 201-300)
... continue until all ~6,962 Steam icons are done

After Steam is complete, run PS5:
{
  "platform_ids": [1],  // PS5
  "batch_size": 50,
  "offset": 0
}
*/

-- ============================================
-- Monitor Progress
-- ============================================
SELECT 
    p.code as platform,
    COUNT(*) FILTER (WHERE a.proxied_icon_url IS NOT NULL) as proxied,
    COUNT(*) FILTER (WHERE a.proxied_icon_url IS NULL) as not_proxied,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE a.proxied_icon_url IS NOT NULL) / COUNT(*), 1) as percent_complete
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
WHERE p.code IN ('Steam', 'PS5', 'PSVITA')
GROUP BY p.code
ORDER BY not_proxied DESC;
