-- Check what the games table actually is

-- Check if it's a view or table
SELECT 
  tablename as name,
  'table' as type
FROM pg_tables
WHERE tablename IN ('games', 'games_v2')
UNION
SELECT 
  viewname as name,
  'view' as type
FROM pg_views
WHERE viewname IN ('games', 'games_v2');

-- Check games table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'games'
ORDER BY ordinal_position;

-- Check what get_grouped_games_fast returns
SELECT * FROM get_grouped_games_fast(NULL, 'psn', 5, 0)
LIMIT 3;
