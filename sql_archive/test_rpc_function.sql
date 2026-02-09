-- Test the actual RPC function that the app calls

-- Test with no search (should show 11-11)
SELECT * FROM get_grouped_games_fast(
  search_query := NULL,
  platform_filter := NULL,
  result_limit := 50,
  result_offset := 0,
  sort_by := 'name_asc'
)
WHERE name ILIKE '%11-11%';

-- Test with "11" search (what user typed)
SELECT * FROM get_grouped_games_fast(
  search_query := '11',
  platform_filter := NULL,
  result_limit := 50,
  result_offset := 0,
  sort_by := 'name_asc'
);

-- Check if there's a return type mismatch
SELECT 
  proname,
  prorettype::regtype,
  pg_get_function_result(oid) as result_signature
FROM pg_proc
WHERE proname = 'get_grouped_games_fast';

-- Check view column types vs function return types
SELECT 
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'grouped_games_cache'
ORDER BY ordinal_position;
