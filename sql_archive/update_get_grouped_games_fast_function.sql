-- Update get_grouped_games_fast function to include proxied_cover_url
-- This function returns all games for the Browse All Games catalog

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
  game_title_ids BIGINT[],
  total_achievements INT,
  primary_game_id BIGINT
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    gg.group_key as group_id,
    gt.name,
    gt.cover_url,
    gt.proxied_cover_url,
    gg.platforms,
    gg.game_title_ids,
    (SELECT COUNT(*)::INT FROM achievements WHERE game_title_id = gg.primary_game_id) as total_achievements,
    gg.primary_game_id
  FROM game_groups gg
  JOIN game_titles gt ON gt.id = gg.primary_game_id
  WHERE 
    (search_query IS NULL OR gt.name ILIKE '%' || search_query || '%')
    AND (platform_filter IS NULL OR platform_filter = ANY(gg.platforms))
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN gt.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN gt.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO anon;
