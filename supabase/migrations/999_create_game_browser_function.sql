-- Create a function to get games with their platforms efficiently
-- This runs on the database server and avoids client-side complexity

CREATE OR REPLACE FUNCTION get_games_with_platforms(
  search_query TEXT DEFAULT NULL,
  platform_filter TEXT DEFAULT NULL,
  result_limit INT DEFAULT 100,
  result_offset INT DEFAULT 0,
  sort_by TEXT DEFAULT 'name_asc'
)
RETURNS TABLE (
  id BIGINT,
  name TEXT,
  cover_url TEXT,
  platforms TEXT[] -- Array of platforms
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    gt.id,
    gt.name,
    gt.cover_url,
    ARRAY_AGG(DISTINCT a.platform) FILTER (WHERE a.platform IS NOT NULL) as platforms
  FROM game_titles gt
  LEFT JOIN achievements a ON a.game_title_id = gt.id
  WHERE 
    (search_query IS NULL OR gt.name ILIKE '%' || search_query || '%')
    AND (
      platform_filter IS NULL 
      OR EXISTS (
        SELECT 1 FROM achievements a2 
        WHERE a2.game_title_id = gt.id 
        AND a2.platform = platform_filter
      )
    )
  GROUP BY gt.id, gt.name, gt.cover_url
  HAVING COUNT(a.id) > 0  -- Only games with achievements
  ORDER BY
    CASE 
      WHEN sort_by = 'name_asc' THEN gt.name
    END ASC,
    CASE 
      WHEN sort_by = 'name_desc' THEN gt.name
    END DESC,
    CASE 
      WHEN sort_by = 'release_asc' THEN gt.release_date
    END ASC NULLS LAST,
    CASE 
      WHEN sort_by = 'release_desc' THEN gt.release_date
    END DESC NULLS LAST
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_games_with_platforms TO authenticated;
GRANT EXECUTE ON FUNCTION get_games_with_platforms TO anon;
