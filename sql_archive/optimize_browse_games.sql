-- ============================================================================
-- Optimize Browse Games - Materialized View Approach
-- ============================================================================
-- Problem: get_grouped_games_fast runs 5 subqueries per row (platforms, platform_ids, platform_game_ids, total_achievements)
-- Solution: Pre-compute grouped game data in a materialized view, refresh periodically

-- Step 1: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_games_name_lower ON games (LOWER(TRIM(name)));
CREATE INDEX IF NOT EXISTS idx_games_platform_id ON games (platform_id);
CREATE INDEX IF NOT EXISTS idx_achievements_composite ON achievements (platform_id, platform_game_id);
CREATE INDEX IF NOT EXISTS idx_games_composite ON games (platform_id, platform_game_id);

-- Step 2: Create materialized view with pre-aggregated data
DROP MATERIALIZED VIEW IF EXISTS grouped_games_cache CASCADE;

CREATE MATERIALIZED VIEW grouped_games_cache AS
WITH distinct_game_platforms AS (
  -- First get distinct combinations of game name and platform
  SELECT DISTINCT ON (LOWER(TRIM(g.name)), g.platform_id)
    LOWER(TRIM(g.name)) as normalized_name,
    g.name,
    g.platform_id,
    g.platform_game_id,
    g.cover_url,
    p.code as platform_code,
    p.name as platform_name
  FROM games g
  JOIN platforms p ON p.id = g.platform_id
  ORDER BY LOWER(TRIM(g.name)), g.platform_id, g.name
),
game_groups AS (
  SELECT 
    dgp.normalized_name,
    MIN(dgp.name) as display_name,  -- Use first alphabetically for consistency
    -- Pick primary game fields (prefer PS5 > Xbox One > Steam > others)
    (ARRAY_AGG(dgp.platform_id ORDER BY 
        CASE dgp.platform_id 
          WHEN 1 THEN 1   -- PS5
          WHEN 11 THEN 2  -- Xbox One
          WHEN 5 THEN 3   -- Steam
          WHEN 2 THEN 4   -- PS4
          WHEN 12 THEN 5  -- Xbox Series X
          ELSE 99
        END,
        dgp.platform_id
    ))[1] as primary_platform_id,
    (ARRAY_AGG(dgp.platform_game_id ORDER BY 
        CASE dgp.platform_id 
          WHEN 1 THEN 1   -- PS5
          WHEN 11 THEN 2  -- Xbox One
          WHEN 5 THEN 3   -- Steam
          WHEN 2 THEN 4   -- PS4
          WHEN 12 THEN 5  -- Xbox Series X
          ELSE 99
        END,
        dgp.platform_id
    ))[1] as primary_game_id,
    (ARRAY_AGG(dgp.cover_url ORDER BY 
        CASE dgp.platform_id 
          WHEN 1 THEN 1   -- PS5
          WHEN 11 THEN 2  -- Xbox One
          WHEN 5 THEN 3   -- Steam
          WHEN 2 THEN 4   -- PS4
          WHEN 12 THEN 5  -- Xbox Series X
          ELSE 99
        END,
        dgp.platform_id
    ))[1] as primary_cover_url,
    -- Aggregate platform data together to maintain alignment (ordered by platform_id)
    ARRAY_AGG(dgp.platform_code ORDER BY dgp.platform_id) as platforms,
    ARRAY_AGG(dgp.platform_name ORDER BY dgp.platform_id) as platform_names,
    ARRAY_AGG(dgp.platform_id ORDER BY dgp.platform_id) as platform_ids,
    ARRAY_AGG(dgp.platform_game_id ORDER BY dgp.platform_id) as platform_game_ids
  FROM distinct_game_platforms dgp
  GROUP BY dgp.normalized_name
),
achievement_counts AS (
  SELECT 
    LOWER(TRIM(g.name)) as normalized_name,
    COUNT(DISTINCT a.platform_achievement_id) as total_achievements
  FROM games g
  LEFT JOIN achievements a ON a.platform_id = g.platform_id 
    AND a.platform_game_id = g.platform_game_id
  GROUP BY LOWER(TRIM(g.name))
)
SELECT 
  gg.normalized_name,
  gg.display_name as name,
  gg.primary_cover_url as cover_url,
  gg.primary_platform_id,
  gg.primary_game_id,
  gg.platforms,
  gg.platform_names,
  gg.platform_ids,
  gg.platform_game_ids,
  COALESCE(ac.total_achievements, 0)::INT as total_achievements
FROM game_groups gg
LEFT JOIN achievement_counts ac ON ac.normalized_name = gg.normalized_name;

-- Create indexes on materialized view
CREATE INDEX idx_grouped_games_name ON grouped_games_cache (normalized_name);
CREATE INDEX idx_grouped_games_display_name ON grouped_games_cache (name);
CREATE INDEX idx_grouped_games_primary_platform ON grouped_games_cache (primary_platform_id);

-- Step 3: Rewrite function to use materialized view
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
  platform_names TEXT[],
  platform_ids BIGINT[],
  platform_game_ids TEXT[],
  total_achievements INT,
  primary_platform_id BIGINT,
  primary_game_id_str TEXT,
  primary_game_id TEXT,
  proxied_cover_url TEXT
) 
LANGUAGE plpgsql
AS $$
DECLARE
  filter_platform_id INT;
BEGIN
  -- Map platform filter to platform_id
  CASE LOWER(platform_filter)
    WHEN 'psn' THEN filter_platform_id := 1;  -- PS5
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
    ggc.normalized_name as group_id,
    ggc.name,
    ggc.cover_url,
    ggc.platforms,
    ggc.platform_names,
    ggc.platform_ids,
    ggc.platform_game_ids,
    ggc.total_achievements,
    ggc.primary_platform_id,
    ggc.primary_game_id as primary_game_id_str,
    ggc.primary_game_id as primary_game_id,
    ggc.cover_url as proxied_cover_url
  FROM grouped_games_cache ggc
  WHERE 
    (search_query IS NULL OR ggc.name ILIKE '%' || search_query || '%')
    AND (filter_platform_id IS NULL OR filter_platform_id = ANY(ggc.platform_ids))
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN ggc.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN ggc.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant permissions
GRANT SELECT ON grouped_games_cache TO authenticated;
GRANT SELECT ON grouped_games_cache TO anon;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO anon;

-- Step 4: Create function to refresh cache (call after syncs)
CREATE OR REPLACE FUNCTION refresh_grouped_games_cache()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY grouped_games_cache;
END;
$$;

GRANT EXECUTE ON FUNCTION refresh_grouped_games_cache TO authenticated;

-- Initial refresh
REFRESH MATERIALIZED VIEW grouped_games_cache;

-- Test query
SELECT 
  name,
  primary_platform_id,
  primary_game_id,
  platform_names,
  platforms,
  total_achievements
FROM get_grouped_games_fast(NULL, 'xbox', 10, 0)
ORDER BY total_achievements DESC
LIMIT 10;
