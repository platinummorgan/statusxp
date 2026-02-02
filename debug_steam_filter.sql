-- Debug Steam filter issue

-- 1. Check if grouped_games_cache has any Steam-only games
SELECT COUNT(*) as steam_only_games
FROM grouped_games_cache
WHERE platform_ids = ARRAY[4]::BIGINT[];

-- 2. Check total Steam games in cache (including multi-platform)
SELECT COUNT(*) as total_steam_games
FROM grouped_games_cache
WHERE 4 = ANY(platform_ids);

-- 3. Test the RPC directly with lowercase 'steam'
SELECT COUNT(*) FROM get_grouped_games_fast(
  search_query := NULL,
  platform_filter := 'steam',
  result_limit := 1000,
  result_offset := 0,
  sort_by := 'name_asc'
);

-- 4. Check the CASE statement mapping in the function
SELECT 
  'psn' as input,
  CASE LOWER('psn')
    WHEN 'psn' THEN 1
    WHEN 'playstation' THEN 1
    WHEN 'ps5' THEN 1
    WHEN 'ps4' THEN 2
    WHEN 'ps3' THEN 5
    WHEN 'psvita' THEN 9
    WHEN 'xbox' THEN 11
    WHEN 'xbox360' THEN 10
    WHEN 'xboxone' THEN 11
    WHEN 'xboxseriesx' THEN 12
    WHEN 'steam' THEN 4
    ELSE NULL
  END as mapped_id
UNION ALL
SELECT 
  'steam' as input,
  CASE LOWER('steam')
    WHEN 'psn' THEN 1
    WHEN 'playstation' THEN 1
    WHEN 'ps5' THEN 1
    WHEN 'ps4' THEN 2
    WHEN 'ps3' THEN 5
    WHEN 'psvita' THEN 9
    WHEN 'xbox' THEN 11
    WHEN 'xbox360' THEN 10
    WHEN 'xboxone' THEN 11
    WHEN 'xboxseriesx' THEN 12
    WHEN 'steam' THEN 4
    ELSE NULL
  END as mapped_id;
