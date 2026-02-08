-- Check if activity feed tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('activity_feed', 'user_stat_snapshots', 'activity_feed_views')
ORDER BY table_name;

-- Check if the RPC function exists
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name = 'get_activity_feed_grouped';
