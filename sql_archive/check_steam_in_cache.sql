-- Check Steam games in grouped_games_cache

SELECT 
  name,
  cover_url,
  platforms,
  platform_ids,
  primary_platform_id
FROM grouped_games_cache
WHERE 4 = ANY(platform_ids)
LIMIT 20;

-- Test the RPC with steam filter
SELECT * FROM get_grouped_games_fast(
  search_query := NULL,
  platform_filter := 'steam',
  result_limit := 20,
  result_offset := 0,
  sort_by := 'name_asc'
);
