-- FIX: Ensure ALL existing profiles have show_on_leaderboard = true by default
-- The migration added the column but didn't backfill existing rows

UPDATE profiles 
SET show_on_leaderboard = true
WHERE show_on_leaderboard IS NULL 
   OR show_on_leaderboard = false;

-- Verify how many were updated
SELECT 
  COUNT(*) FILTER (WHERE show_on_leaderboard = true) as visible_count,
  COUNT(*) FILTER (WHERE show_on_leaderboard = false) as hidden_count,
  COUNT(*) FILTER (WHERE show_on_leaderboard IS NULL) as null_count,
  COUNT(*) as total_profiles
FROM profiles;

-- Refresh leaderboard caches to include everyone (only if they exist)
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
