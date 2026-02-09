-- ============================================================================
-- Fix Browse Games - Add platform_id and platform_game_id to results
-- ============================================================================
-- Problem: get_grouped_games_fast needs to return platform_id and platform_game_id
-- Solution: Query directly from games table (game_titles table no longer exists)

-- Drop existing function first (return type is changing)
DROP FUNCTION IF EXISTS get_grouped_games_fast(text, text, integer, integer, text);

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
  platforms TEXT[],
  platform_ids BIGINT[],
  platform_game_ids TEXT[],
  total_achievements INT,
  primary_platform_id BIGINT,
  primary_game_id_str TEXT,
  primary_game_id TEXT,  -- Alias for compatibility with Dart code
  proxied_cover_url TEXT
) 
LANGUAGE plpgsql
AS $$
DECLARE
  filter_platform_id INT;
BEGIN
  -- Map platform filter to platform_id
  CASE LOWER(platform_filter)
    WHEN 'psn' THEN filter_platform_id := 1;  -- PS5 (default PSN)
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

  RETURN QUERY
  SELECT 
    g.name as group_id,
    g.name,
    g.cover_url,
    -- Get all platforms for this game name (case insensitive match)
    ARRAY(
      SELECT DISTINCT p.code
      FROM games g2
      JOIN platforms p ON p.id = g2.platform_id
      WHERE LOWER(TRIM(g2.name)) = LOWER(TRIM(g.name))
      ORDER BY p.code
    ) as platforms,
    -- Get all platform_ids for this game name
    ARRAY(
      SELECT DISTINCT g2.platform_id
      FROM games g2
      WHERE LOWER(TRIM(g2.name)) = LOWER(TRIM(g.name))
      ORDER BY g2.platform_id
    ) as platform_ids,
    -- Get all platform_game_ids for this game name
    ARRAY(
      SELECT DISTINCT g2.platform_game_id
      FROM games g2
      WHERE LOWER(TRIM(g2.name)) = LOWER(TRIM(g.name))
      ORDER BY g2.platform_game_id
    ) as platform_game_ids,
    -- Count achievements across all platforms for this game
    -- For Xbox games (10,11,12), check all Xbox platforms for achievements
    (SELECT COUNT(*)::INT 
     FROM achievements a
     WHERE (a.platform_id = g.platform_id AND a.platform_game_id = g.platform_game_id)
        OR (g.platform_id IN (10, 11, 12) AND a.platform_id IN (10, 11, 12) 
            AND EXISTS (
              SELECT 1 FROM games g2 
              WHERE g2.platform_id = a.platform_id 
                AND g2.platform_game_id = a.platform_game_id
                AND LOWER(TRIM(g2.name)) = LOWER(TRIM(g.name))
            ))
    ) as total_achievements,
    -- Primary platform_id (filtered or first available)
    g.platform_id as primary_platform_id,
    -- Primary platform_game_id
    g.platform_game_id as primary_game_id_str,
    g.platform_game_id as primary_game_id,  -- Alias for Dart compatibility
    g.cover_url as proxied_cover_url  -- For compatibility
  FROM (
    SELECT DISTINCT ON (LOWER(TRIM(g.name)))
      g.platform_id,
      g.platform_game_id,
      g.name,
      g.cover_url
    FROM games g
    WHERE 
      (search_query IS NULL OR g.name ILIKE '%' || search_query || '%')
      AND (filter_platform_id IS NULL OR g.platform_id = filter_platform_id)
    ORDER BY 
      LOWER(TRIM(g.name)),
      CASE WHEN g.platform_id = filter_platform_id THEN 0 ELSE 1 END,
      g.platform_id
  ) g
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN g.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN g.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO anon;

-- Test with PSN filter
SELECT 
  name,
  primary_platform_id,
  primary_game_id_str,
  platform_ids,
  platform_game_ids,
  total_achievements
FROM get_grouped_games_fast(NULL, 'psn', 5, 0)
LIMIT 5;

-- Test with Xbox filter to verify cross-platform achievement counting
SELECT 
  name,
  primary_platform_id,
  primary_game_id,
  platforms,
  total_achievements
FROM get_grouped_games_fast(NULL, 'xbox', 10, 0)
ORDER BY total_achievements DESC
LIMIT 10;
