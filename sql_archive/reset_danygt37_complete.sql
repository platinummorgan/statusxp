-- Reset DanyGT37's sync status AND clear bad data to force fresh sync

-- Clear the test achievement we inserted
DELETE FROM user_achievements 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Reset sync timestamps and progress
UPDATE profiles
SET 
  last_psn_sync_at = NULL,
  last_steam_sync_at = NULL,
  psn_sync_progress = 0,
  steam_sync_progress = 0,
  psn_sync_status = NULL,
  steam_sync_status = NULL
WHERE id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Refresh the leaderboard caches to clear stale data
SELECT refresh_psn_leaderboard_cache();
SELECT refresh_steam_leaderboard_cache();

-- Verify everything is reset
SELECT 
  'Profile Reset Status' as section,
  display_name,
  last_psn_sync_at,
  last_steam_sync_at,
  psn_sync_progress,
  steam_sync_progress,
  psn_sync_status,
  steam_sync_status
FROM profiles
WHERE id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Verify user_achievements cleared
SELECT 
  'Achievements Cleared' as section,
  COUNT(*) as should_be_zero
FROM user_achievements
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check leaderboard cache status
SELECT 
  'PSN Cache' as section,
  display_name,
  platinum_count,
  total_games
FROM psn_leaderboard_cache
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

SELECT 
  'Steam Cache' as section,
  display_name,
  achievement_count,
  total_games
FROM steam_leaderboard_cache
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
