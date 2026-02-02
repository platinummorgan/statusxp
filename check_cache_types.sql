-- Check what type each cache is (table vs view)
SELECT 
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_name IN ('xbox_leaderboard_cache', 'steam_leaderboard_cache', 'leaderboard_cache', 'psn_leaderboard_cache')
  AND table_schema = 'public';
