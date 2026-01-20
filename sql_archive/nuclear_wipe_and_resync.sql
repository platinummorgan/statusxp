-- ============================================
-- NUCLEAR OPTION: Clean Database Wipe & Resync
-- USE WITH EXTREME CAUTION
-- ============================================
-- This script will DELETE all user gaming data and force a clean resync
-- ============================================

-- What will be DELETED:
-- ✓ user_games (all game progress data)
-- ✓ user_achievements (all earned achievements)
-- ✓ game_titles (all game metadata)
-- ✓ achievements (all achievement definitions)
-- ✓ psn_leaderboard_cache (all leaderboard data)
--
-- What will be PRESERVED:
-- ✓ User accounts (profiles, auth)
-- ✓ Platform links (PSN/Xbox/Steam connections)
-- ✓ User preferences and settings
-- ============================================

BEGIN;

-- ============================================
-- STEP 1: Backup counts before deletion
-- ============================================
SELECT 'BEFORE_WIPE' as status,
  (SELECT COUNT(*) FROM user_games) as user_games_count,
  (SELECT COUNT(*) FROM user_achievements) as user_achievements_count,
  (SELECT COUNT(*) FROM game_titles) as game_titles_count,
  (SELECT COUNT(*) FROM achievements) as achievements_count,
  (SELECT COUNT(DISTINCT user_id) FROM user_games) as users_with_games;

-- ============================================
-- STEP 2: Reset sync status for all users
-- ============================================
UPDATE profiles
SET psn_sync_status = 'never_synced',
    psn_sync_progress = 0,
    psn_sync_error = NULL,
    last_psn_sync_at = NULL
WHERE psn_account_id IS NOT NULL;

UPDATE profiles  
SET xbox_sync_status = 'never_synced',
    xbox_sync_progress = 0,
    xbox_sync_error = NULL,
    last_xbox_sync_at = NULL
WHERE xbox_xuid IS NOT NULL;

-- ============================================
-- STEP 3: Clear leaderboard cache
-- ============================================
TRUNCATE TABLE psn_leaderboard_cache CASCADE;

-- ============================================
-- STEP 4: Delete all user gaming data
-- These cascade to related tables
-- ============================================
TRUNCATE TABLE user_achievements CASCADE;
TRUNCATE TABLE user_games CASCADE;

-- ============================================
-- STEP 5: Delete all achievement definitions
-- ============================================
TRUNCATE TABLE achievements CASCADE;

-- ============================================
-- STEP 6: Delete all game titles
-- ============================================
TRUNCATE TABLE game_titles CASCADE;

-- ============================================
-- STEP 7: Verify deletion
-- ============================================
SELECT 'AFTER_WIPE' as status,
  (SELECT COUNT(*) FROM user_games) as user_games_count,
  (SELECT COUNT(*) FROM user_achievements) as user_achievements_count,
  (SELECT COUNT(*) FROM game_titles) as game_titles_count,
  (SELECT COUNT(*) FROM achievements) as achievements_count,
  (SELECT COUNT(*) FROM profiles WHERE psn_sync_status != 'never_synced' AND psn_account_id IS NOT NULL) as users_still_synced;

-- ============================================
-- STEP 8: Show what's preserved
-- ============================================
SELECT 'PRESERVED_DATA' as status,
  (SELECT COUNT(*) FROM profiles WHERE psn_account_id IS NOT NULL) as psn_linked_users,
  (SELECT COUNT(*) FROM profiles WHERE xbox_xuid IS NOT NULL) as xbox_linked_users,
  (SELECT COUNT(*) FROM platforms) as platforms_count;

-- ============================================
-- COMMIT OR ROLLBACK
-- ============================================
-- Review the AFTER_WIPE results above.
-- ALL gaming data should be 0.
-- If correct, COMMIT. Otherwise ROLLBACK.

-- Uncomment ONE of these:
-- COMMIT;
-- ROLLBACK;

-- ============================================
-- NEXT STEPS AFTER COMMIT:
-- ============================================
-- 1. Fix psn-sync.js bug (platform.id resolution)
-- 2. Deploy fixed sync service
-- 3. Notify users to resync via app
-- 4. Monitor sync logs for errors
-- 5. Run audit_database_integrity.sql after resyncs complete
