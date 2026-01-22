-- Check how many PlayStation and Xbox game covers need backfilling
-- Run this first to see the scope

-- PlayStation platforms: 1, 2, 5, 9 (PSN, PS3, PS4, PS5, PSVITA)
-- Xbox platforms: 10, 11, 12 (XBOX360, XBOXONE, XBOXSERIESX)

SELECT 
  p.name as platform_name,
  COUNT(*) as games_needing_backfill
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.cover_url IS NOT NULL
  AND g.cover_url NOT LIKE '%supabase%'
  AND g.cover_url NOT LIKE '%cloudfront%'
  AND g.platform_id IN (1, 2, 5, 9, 10, 11, 12)
GROUP BY p.name
ORDER BY COUNT(*) DESC;

-- See sample of URLs that need fixing
SELECT 
  p.name,
  g.platform_game_id,
  g.cover_url
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.cover_url IS NOT NULL
  AND g.cover_url NOT LIKE '%supabase%'
  AND g.cover_url NOT LIKE '%cloudfront%'
  AND g.platform_id IN (1, 2, 5, 9, 10, 11, 12)
LIMIT 10;
