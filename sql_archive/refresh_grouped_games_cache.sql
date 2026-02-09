-- Check if grouped_games_cache materialized view needs refresh
-- This view caches game covers for "Browse All Games" screen

-- Check when it was last refreshed (if pg_stat_user_tables tracks it)
SELECT 
  schemaname,
  matviewname,
  last_autovacuum,
  n_live_tup as row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public' AND relname = 'grouped_games_cache';

-- Check sample games to see if covers are null
SELECT 
  name,
  cover_url,
  primary_platform_id,
  primary_game_id,
  platforms
FROM grouped_games_cache
ORDER BY name
LIMIT 20;

-- Check how many games have null covers
SELECT 
  COUNT(*) as total_games,
  COUNT(cover_url) as games_with_cover,
  COUNT(*) - COUNT(cover_url) as games_without_cover
FROM grouped_games_cache;

-- Refresh the materialized view to pull latest cover URLs from games table
REFRESH MATERIALIZED VIEW grouped_games_cache;

-- Verify covers are now populated
SELECT 
  name,
  cover_url,
  platforms
FROM grouped_games_cache
WHERE cover_url IS NOT NULL
ORDER BY name
LIMIT 10;
