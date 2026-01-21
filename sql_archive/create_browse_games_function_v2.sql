-- ============================================================================
-- CREATE Browse Games Function for V2 Schema
-- ============================================================================
-- The app expects a function that returns games grouped across platforms
-- In V2, we don't have game_groups, so we need to query games table directly
-- ============================================================================

DROP FUNCTION IF EXISTS get_grouped_games_fast(TEXT, TEXT, INT, INT, TEXT);

CREATE OR REPLACE FUNCTION get_grouped_games_fast(
  search_query TEXT DEFAULT NULL,
  platform_filter TEXT DEFAULT NULL,
  result_limit INT DEFAULT 100,
  result_offset INT DEFAULT 0,
  sort_by TEXT DEFAULT 'name_asc'
)
RETURNS TABLE (
  group_id TEXT,
  name TEXT,
  cover_url TEXT,
  proxied_cover_url TEXT,
  platforms TEXT[],
  platform_ids BIGINT[],
  platform_game_ids TEXT[],
  all_platforms TEXT[],
  total_achievements INT,
  primary_game_id BIGINT,
  platform_id BIGINT,
  platform_game_id TEXT
) 
LANGUAGE plpgsql
AS $$
DECLARE
  filter_platform_id INT;
BEGIN
  -- Map platform filter string to platform_id
  IF platform_filter IS NOT NULL THEN
    CASE LOWER(platform_filter)
      WHEN 'psn' THEN filter_platform_id := 1;  -- PS5 (default PSN)
      WHEN 'playstation' THEN filter_platform_id := 1;
      WHEN 'ps5' THEN filter_platform_id := 1;
      WHEN 'ps4' THEN filter_platform_id := 2;
      WHEN 'ps3' THEN filter_platform_id := 5;
      WHEN 'psvita' THEN filter_platform_id := 9;
      WHEN 'steam' THEN filter_platform_id := 4;
      WHEN 'xbox' THEN filter_platform_id := 11;  -- Xbox One (default)
      WHEN 'xbox360' THEN filter_platform_id := 10;
      WHEN 'xboxone' THEN filter_platform_id := 11;
      WHEN 'xboxseriesx' THEN filter_platform_id := 12;
      ELSE filter_platform_id := NULL;
    END CASE;
  END IF;

  RETURN QUERY
  SELECT 
    CONCAT(g.platform_id::text, '-', g.platform_game_id) as group_id,
    g.name,
    g.cover_url,
    g.cover_url as proxied_cover_url,  -- Already proxied in V2
    ARRAY[
      CASE 
        WHEN g.platform_id = 1 THEN 'psn'
        WHEN g.platform_id = 2 THEN 'ps3'
        WHEN g.platform_id = 4 THEN 'ps4'
        WHEN g.platform_id = 5 THEN 'steam'
        WHEN g.platform_id = 10 THEN 'xbox360'
        WHEN g.platform_id = 11 THEN 'xboxone'
        WHEN g.platform_id = 12 THEN 'xboxseriesx'
        ELSE 'unknown'
      END
    ] as platforms,
    ARRAY[g.platform_id::BIGINT] as platform_ids,
    ARRAY[g.platform_game_id] as platform_game_ids,
    ARRAY[
      CASE 
        WHEN g.platform_id = 1 THEN 'PSN'
        WHEN g.platform_id = 2 THEN 'PS3'
        WHEN g.platform_id = 4 THEN 'PS4'
        WHEN g.platform_id = 5 THEN 'Steam'
        WHEN g.platform_id = 10 THEN 'Xbox360'
        WHEN g.platform_id = 11 THEN 'XboxOne'
        WHEN g.platform_id = 12 THEN 'XboxSeriesX'
        ELSE 'Unknown'
      END
    ] as all_platforms,
    (
      SELECT COUNT(*)::INT 
      FROM achievements a 
      WHERE a.platform_id = g.platform_id 
        AND a.platform_game_id = g.platform_game_id
    ) as total_achievements,
    0::BIGINT as primary_game_id,
    g.platform_id,
    g.platform_game_id
  FROM games g
  WHERE 
    (search_query IS NULL OR g.name ILIKE '%' || search_query || '%')
    AND (filter_platform_id IS NULL OR g.platform_id = filter_platform_id)
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN g.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN g.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO anon;

-- Test it
SELECT name, platforms[1] as platform, platform_id
FROM get_grouped_games_fast(NULL, 'steam', 10, 0)
LIMIT 10;
