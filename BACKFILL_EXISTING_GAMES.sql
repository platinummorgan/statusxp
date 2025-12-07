-- ============================================================================
-- BACKFILL: Update existing user_games to set correct platform_id
-- This updates all your existing Xbox and Steam games that are showing as "unknown"
-- ============================================================================

-- Update Xbox games: Look for game_titles with xbox metadata and set XBOXONE platform
UPDATE user_games ug
SET platform_id = (SELECT id FROM platforms WHERE code = 'XBOXONE' LIMIT 1)
WHERE ug.platform_id IS NULL
  AND ug.xbox_total_achievements IS NOT NULL
  AND ug.xbox_total_achievements > 0;

-- Update Steam games: Look for game_titles with Steam external_id pattern
UPDATE user_games ug
SET platform_id = (SELECT id FROM platforms WHERE code = 'Steam' LIMIT 1)
FROM game_titles gt
WHERE ug.game_title_id = gt.id
  AND ug.platform_id IS NULL
  AND gt.external_id ~ '^\d+$'  -- Steam app IDs are numeric
  AND gt.xbox_title_id IS NULL; -- Exclude Xbox games

-- Update PlayStation games based on trophy data
UPDATE user_games ug
SET platform_id = (
  CASE 
    WHEN gt.external_id LIKE 'NPWR%' THEN (SELECT id FROM platforms WHERE code = 'PS5' LIMIT 1)
    WHEN gt.external_id LIKE 'CUSA%' THEN (SELECT id FROM platforms WHERE code = 'PS4' LIMIT 1)
    WHEN gt.external_id LIKE 'NPUA%' THEN (SELECT id FROM platforms WHERE code = 'PS3' LIMIT 1)
    WHEN gt.external_id LIKE 'PCSA%' OR gt.external_id LIKE 'PCSE%' THEN (SELECT id FROM platforms WHERE code = 'PSVITA' LIMIT 1)
    ELSE (SELECT id FROM platforms WHERE code = 'PS4' LIMIT 1)
  END
)
FROM game_titles gt
WHERE ug.game_title_id = gt.id
  AND ug.platform_id IS NULL
  AND (ug.bronze_trophies IS NOT NULL OR ug.silver_trophies IS NOT NULL OR ug.gold_trophies IS NOT NULL);

-- Verify the update worked
SELECT 
  p.code as platform,
  COUNT(*) as game_count
FROM user_games ug
LEFT JOIN platforms p ON ug.platform_id = p.id
GROUP BY p.code
ORDER BY game_count DESC;

-- Show any remaining NULL platform_ids (should be 0)
SELECT COUNT(*) as remaining_unknown
FROM user_games
WHERE platform_id IS NULL;
