-- Fix browse games function for V2 schema
-- Replaces get_grouped_games_fast to work with new schema

-- Drop old function first (return type changed)
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
  proxied_cover_url TEXT,
  platforms TEXT[],
  platform_ids BIGINT[],
  platform_game_ids TEXT[],
  total_achievements INT,
  primary_platform_id BIGINT,
  primary_game_id TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    g.platform_game_id as group_id,
    g.name,
    g.cover_url,
    g.cover_url as proxied_cover_url,
    ARRAY[p.code] as platforms,
    ARRAY[g.platform_id] as platform_ids,
    ARRAY[g.platform_game_id] as platform_game_ids,
    (SELECT COUNT(*)::INT 
     FROM achievements a 
     WHERE a.platform_id = g.platform_id 
       AND a.platform_game_id = g.platform_game_id) as total_achievements,
    g.platform_id as primary_platform_id,
    g.platform_game_id as primary_game_id
  FROM games g
  JOIN platforms p ON p.id = g.platform_id
  WHERE 
    (search_query IS NULL OR g.name ILIKE '%' || search_query || '%')
    AND (platform_filter IS NULL OR 
         CASE 
           WHEN platform_filter = 'psn' THEN p.id = 1
           WHEN platform_filter = 'xbox' THEN p.id IN (10, 11, 12)
           WHEN platform_filter = 'steam' THEN p.id = 5
           ELSE p.code = platform_filter
         END)
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
