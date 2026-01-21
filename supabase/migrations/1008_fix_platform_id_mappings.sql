-- Migration: 1008_fix_platform_id_mappings.sql
-- Created: 2025-01-XX
-- Description: Fix incorrect platform_id mappings in get_grouped_games_fast function
--
-- BUG: The function had wrong mappings:
--   - PS3 mapped to 2 (should be 5)
--   - PS4 mapped to 4 (should be 2)
--   - Steam mapped to 5 (should be 4)
--
-- CORRECT PLATFORM IDs (from psn-sync.js and database):
--   PS5 = 1, PS4 = 2, PS3 = 5, PSVITA = 9
--   Xbox360 = 10, XboxOne = 11, XboxSeriesX = 12
--   Steam = 4

-- Drop and recreate the function with correct platform_id mappings
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
  -- Map platform filter to platform_id (CORRECTED MAPPINGS)
  CASE LOWER(platform_filter)
    WHEN 'psn' THEN filter_platform_id := 1;  -- PS5 (default PSN)
    WHEN 'ps5' THEN filter_platform_id := 1;
    WHEN 'ps4' THEN filter_platform_id := 2;  -- FIXED: was 4
    WHEN 'ps3' THEN filter_platform_id := 5;  -- FIXED: was 2
    WHEN 'psvita' THEN filter_platform_id := 9;
    WHEN 'steam' THEN filter_platform_id := 4;  -- FIXED: was 5
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
    -- Get platform names (aligned with platform_ids)
    ARRAY(
      SELECT p.name
      FROM games g2
      JOIN platforms p ON p.id = g2.platform_id
      WHERE LOWER(TRIM(g2.name)) = LOWER(TRIM(g.name))
      GROUP BY g2.platform_id, p.name
      ORDER BY g2.platform_id
    ) as platform_names,
    -- Get platform IDs (ordered by platform_id for alignment)
    ARRAY(
      SELECT DISTINCT g2.platform_id
      FROM games g2
      WHERE LOWER(TRIM(g2.name)) = LOWER(TRIM(g.name))
      ORDER BY g2.platform_id
    ) as platform_ids,
    -- Get platform game IDs (aligned with platform_ids)
    ARRAY(
      SELECT g2.platform_game_id
      FROM games g2
      WHERE LOWER(TRIM(g2.name)) = LOWER(TRIM(g.name))
      GROUP BY g2.platform_id, g2.platform_game_id
      ORDER BY g2.platform_id
    ) as platform_game_ids,
    -- Count achievements for primary version
    (
      SELECT COUNT(*)::INT 
      FROM achievements a 
      WHERE a.platform_id = g.platform_id 
        AND a.platform_game_id = g.platform_game_id
    ) as total_achievements,
    g.platform_id as primary_platform_id,
    g.platform_game_id as primary_game_id_str,
    g.platform_game_id as primary_game_id,
    g.cover_url as proxied_cover_url
  FROM (
    SELECT DISTINCT ON (LOWER(TRIM(g3.name)))
      g3.name,
      g3.platform_id,
      g3.platform_game_id,
      g3.cover_url
    FROM games g3
    WHERE 
      (search_query IS NULL OR g3.name ILIKE '%' || search_query || '%')
      AND (filter_platform_id IS NULL OR g3.platform_id = filter_platform_id)
    ORDER BY LOWER(TRIM(g3.name)), 
      -- Priority order for primary version
      CASE g3.platform_id 
        WHEN 1 THEN 1   -- PS5
        WHEN 11 THEN 2  -- Xbox One
        WHEN 4 THEN 3   -- Steam (FIXED: was platform_id 5)
        WHEN 2 THEN 4   -- PS4 (FIXED: was platform_id 4)
        WHEN 12 THEN 5  -- Xbox Series X
        WHEN 5 THEN 6   -- PS3 (FIXED: was platform_id 2)
        ELSE 99
      END
  ) g
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN g.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN g.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO anon;

-- Add comment explaining the fix
COMMENT ON FUNCTION get_grouped_games_fast IS 'Fixed platform_id mappings: PS4=2 (was 4), PS3=5 (was 2), Steam=4 (was 5)';
