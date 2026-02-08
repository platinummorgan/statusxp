-- Migration: Fix platform filter mappings in get_grouped_games_fast
-- Issue: Platform filters not working correctly - PS4 games don't show with PS4 filter
--
-- Root cause: Platform ID mappings are wrong:
--   Current: PS4=4, PS3=2, Steam=5
--   Correct: PS4=2, PS3=5, Steam=4

CREATE OR REPLACE FUNCTION "public"."get_grouped_games_fast"(
  "search_query" "text" DEFAULT NULL::"text", 
  "platform_filter" "text" DEFAULT NULL::"text", 
  "result_limit" integer DEFAULT 100, 
  "result_offset" integer DEFAULT 0, 
  "sort_by" "text" DEFAULT 'name_asc'::"text"
) 
RETURNS TABLE(
  "group_id" "text", 
  "name" "text", 
  "cover_url" "text", 
  "platforms" "text"[], 
  "platform_names" "text"[], 
  "platform_ids" bigint[], 
  "platform_game_ids" "text"[], 
  "total_achievements" integer, 
  "primary_platform_id" bigint, 
  "primary_game_id_str" "text", 
  "primary_game_id" "text", 
  "proxied_cover_url" "text"
)
LANGUAGE "plpgsql"
AS $$
DECLARE
  filter_platform_id INT;
BEGIN
  -- Map platform filter to platform_id (CORRECTED MAPPINGS)
  CASE LOWER(platform_filter)
    WHEN 'psn' THEN filter_platform_id := 1;      -- PS5
    WHEN 'ps5' THEN filter_platform_id := 1;      -- PS5
    WHEN 'ps4' THEN filter_platform_id := 2;      -- PS4 (was 4 - WRONG!)
    WHEN 'ps3' THEN filter_platform_id := 5;      -- PS3 (was 2 - WRONG!)
    WHEN 'psvita' THEN filter_platform_id := 9;   -- PSVita
    WHEN 'steam' THEN filter_platform_id := 4;    -- Steam (was 5 - WRONG!)
    WHEN 'xbox' THEN filter_platform_id := 11;    -- XboxOne
    WHEN 'xbox360' THEN filter_platform_id := 10; -- Xbox360
    WHEN 'xboxone' THEN filter_platform_id := 11; -- XboxOne
    WHEN 'xboxseriesx' THEN filter_platform_id := 12; -- XboxSeriesX
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

COMMENT ON FUNCTION "public"."get_grouped_games_fast" IS 'Fixed platform ID mappings: PS4=2 (was 4), PS3=5 (was 2), Steam=4 (was 5). Jan 31, 2026.';
