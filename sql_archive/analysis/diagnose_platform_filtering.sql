-- ============================================================================
-- Diagnose Platform Filtering Issues
-- ============================================================================
-- Dashboard shows Steam as 0, filters showing wrong games
-- ============================================================================

-- 1. Check all platforms in games table
SELECT 
  platform_id,
  COUNT(*) as game_count,
  CASE 
    WHEN platform_id = 1 THEN 'PS5'
    WHEN platform_id = 2 THEN 'PS3'
    WHEN platform_id = 3 THEN 'PS4'
    WHEN platform_id = 4 THEN 'PS4/PS5?'
    WHEN platform_id = 5 THEN 'Steam'
    WHEN platform_id = 10 THEN 'Xbox360'
    WHEN platform_id = 11 THEN 'XboxOne'
    WHEN platform_id = 12 THEN 'XboxSeriesX'
    ELSE 'Unknown'
  END as platform_name
FROM games
GROUP BY platform_id
ORDER BY platform_id;

-- 2. Check user's game distribution
SELECT 
  platform_id,
  COUNT(*) as game_count,
  CASE 
    WHEN platform_id = 1 THEN 'PS5'
    WHEN platform_id = 2 THEN 'PS3'
    WHEN platform_id = 3 THEN 'PS4'
    WHEN platform_id = 4 THEN 'PS4/PS5?'
    WHEN platform_id = 5 THEN 'Steam'
    WHEN platform_id = 10 THEN 'Xbox360'
    WHEN platform_id = 11 THEN 'XboxOne'
    WHEN platform_id = 12 THEN 'XboxSeriesX'
    ELSE 'Unknown'
  END as platform_name
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_id
ORDER BY platform_id;

-- 3. Check if platforms table exists and what it contains
SELECT * FROM platforms ORDER BY id;

-- 4. Sample PS3 games to confirm platform_id
SELECT name, platform_id, platform_game_id
FROM games
WHERE platform_id = 2
LIMIT 5;

-- 5. Sample Steam games to confirm platform_id
SELECT name, platform_id, platform_game_id
FROM games
WHERE platform_id = 5
LIMIT 5;
