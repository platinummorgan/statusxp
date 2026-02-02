-- Migration: Convert grouped_games_cache from materialized view to regular view
-- Issue: Materialized view requires manual REFRESH, causing game covers to not show in Browse All Games
--
-- Fix: Convert to regular view so it always pulls fresh data from games table

-- Drop the materialized view
DROP MATERIALIZED VIEW IF EXISTS grouped_games_cache;

-- Recreate as a regular view (always fresh, no manual refresh needed)
CREATE OR REPLACE VIEW grouped_games_cache AS
WITH distinct_game_platforms AS (
  SELECT DISTINCT ON (LOWER(TRIM(g.name)), g.platform_id)
    LOWER(TRIM(g.name)) AS normalized_name,
    g.name,
    g.platform_id,
    g.platform_game_id,
    g.cover_url,
    p.code AS platform_code,
    p.name AS platform_name
  FROM games g
  JOIN platforms p ON p.id = g.platform_id
  ORDER BY LOWER(TRIM(g.name)), g.platform_id, g.name
),
game_groups AS (
  SELECT 
    dgp.normalized_name,
    MIN(dgp.name) AS display_name,
    -- Primary platform prioritization: PS5 > Xbox > Steam > PS4 > XboxSeriesX
    (ARRAY_AGG(dgp.platform_id ORDER BY 
      CASE dgp.platform_id
        WHEN 1 THEN 1   -- PS5
        WHEN 11 THEN 2  -- XboxOne
        WHEN 5 THEN 3   -- PS3
        WHEN 2 THEN 4   -- PS4
        WHEN 12 THEN 5  -- XboxSeriesX
        ELSE 99
      END, 
      dgp.platform_id
    ))[1] AS primary_platform_id,
    (ARRAY_AGG(dgp.platform_game_id ORDER BY 
      CASE dgp.platform_id
        WHEN 1 THEN 1
        WHEN 11 THEN 2
        WHEN 5 THEN 3
        WHEN 2 THEN 4
        WHEN 12 THEN 5
        ELSE 99
      END,
      dgp.platform_id
    ))[1] AS primary_game_id,
    (ARRAY_AGG(dgp.cover_url ORDER BY 
      CASE dgp.platform_id
        WHEN 1 THEN 1
        WHEN 11 THEN 2
        WHEN 5 THEN 3
        WHEN 2 THEN 4
        WHEN 12 THEN 5
        ELSE 99
      END,
      dgp.platform_id
    ))[1] AS primary_cover_url,
    ARRAY_AGG(dgp.platform_code ORDER BY dgp.platform_id) AS platforms,
    ARRAY_AGG(dgp.platform_name ORDER BY dgp.platform_id) AS platform_names,
    ARRAY_AGG(dgp.platform_id ORDER BY dgp.platform_id) AS platform_ids,
    ARRAY_AGG(dgp.platform_game_id ORDER BY dgp.platform_id) AS platform_game_ids
  FROM distinct_game_platforms dgp
  GROUP BY dgp.normalized_name
),
achievement_counts AS (
  SELECT 
    LOWER(TRIM(g.name)) AS normalized_name,
    COUNT(DISTINCT a.platform_achievement_id) AS total_achievements
  FROM games g
  LEFT JOIN achievements a ON 
    a.platform_id = g.platform_id 
    AND a.platform_game_id = g.platform_game_id
  GROUP BY LOWER(TRIM(g.name))
)
SELECT 
  gg.normalized_name,
  gg.display_name AS name,
  gg.primary_cover_url AS cover_url,
  gg.primary_platform_id,
  gg.primary_game_id,
  gg.platforms,
  gg.platform_names,
  gg.platform_ids,
  gg.platform_game_ids,
  COALESCE(ac.total_achievements, 0)::INTEGER AS total_achievements
FROM game_groups gg
LEFT JOIN achievement_counts ac ON ac.normalized_name = gg.normalized_name;

COMMENT ON VIEW grouped_games_cache IS 'Game catalog grouped by normalized name. Converted from materialized view to regular view Jan 31, 2026 - always shows fresh game covers without manual refresh.';

-- Grant permissions
GRANT SELECT ON grouped_games_cache TO authenticated;
GRANT SELECT ON grouped_games_cache TO anon;
GRANT SELECT ON grouped_games_cache TO service_role;
