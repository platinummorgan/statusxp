-- Reset ALL users' sync status to force fresh sync
-- This fixes the broken RLS policy issue for everyone

-- Get current stats before reset
SELECT 
  'Before Reset' as section,
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE last_psn_sync_at IS NOT NULL) as psn_synced,
  COUNT(*) FILTER (WHERE last_steam_sync_at IS NOT NULL) as steam_synced,
  COUNT(*) FILTER (WHERE last_xbox_sync_at IS NOT NULL) as xbox_synced
FROM profiles;

-- Reset all sync timestamps and progress for ALL users
UPDATE profiles
SET 
  last_psn_sync_at = NULL,
  last_steam_sync_at = NULL,
  last_xbox_sync_at = NULL,
  psn_sync_progress = 0,
  steam_sync_progress = 0,
  xbox_sync_progress = 0,
  psn_sync_status = NULL,
  steam_sync_status = NULL,
  xbox_sync_status = NULL,
  psn_sync_error = NULL,
  steam_sync_error = NULL,
  xbox_sync_error = NULL;

-- Verify reset
SELECT 
  'After Reset' as section,
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE last_psn_sync_at IS NOT NULL) as psn_synced,
  COUNT(*) FILTER (WHERE last_steam_sync_at IS NOT NULL) as steam_synced,
  COUNT(*) FILTER (WHERE last_xbox_sync_at IS NOT NULL) as xbox_synced
FROM profiles;

-- Refresh all leaderboard caches
SELECT 'Refreshing PSN cache...' as status;
SELECT refresh_psn_leaderboard_cache();

SELECT 'Refreshing Steam cache...' as status;
SELECT refresh_steam_leaderboard_cache();

SELECT 'Refreshing Xbox cache...' as status;
SELECT refresh_xbox_leaderboard_cache();

-- Final cache counts
SELECT 
  'PSN Cache' as cache,
  COUNT(*) as user_count,
  SUM(platinum_count) as total_platinums
FROM psn_leaderboard_cache;

SELECT 
  'Steam Cache' as cache,
  COUNT(*) as user_count,
  SUM(achievement_count) as total_achievements
FROM steam_leaderboard_cache;

SELECT 
  'Xbox Cache' as cache,
  COUNT(*) as user_count,
  SUM(gamerscore) as total_gamerscore
FROM xbox_leaderboard_cache;

SELECT 'Reset complete! All users will re-sync on next login.' as message;
