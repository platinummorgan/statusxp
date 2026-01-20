-- Validation query for v2 schema migration
-- Run this after Migration 118 completes to verify data integrity

-- ============================================================================
-- PART 1: Overall migration counts
-- ============================================================================

SELECT 'Migration Summary' as section;

SELECT 
  'games_v2' as table_name,
  COUNT(*) as total_entries,
  COUNT(DISTINCT platform_id) as platforms,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_games,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_games,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'STEAM') THEN 1 END) as steam_games
FROM games_v2;

SELECT 
  'user_progress_v2' as table_name,
  COUNT(*) as total_entries,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_progress,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_progress,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'STEAM') THEN 1 END) as steam_progress
FROM user_progress_v2;

SELECT 
  'achievements_v2' as table_name,
  COUNT(*) as total_entries,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_achievements,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_achievements,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'STEAM') THEN 1 END) as steam_achievements
FROM achievements_v2;

SELECT 
  'user_achievements_v2' as table_name,
  COUNT(*) as total_entries,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_earned,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_earned,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'STEAM') THEN 1 END) as steam_earned
FROM user_achievements_v2;

-- ============================================================================
-- PART 2: X_imThumper_X's data validation
-- ============================================================================

SELECT 'X_imThumper_X Xbox Data Validation' as section;

-- X_imThumper_X's Xbox stats from v2 schema
SELECT 
  p.display_name,
  p.xbox_gamertag,
  COUNT(DISTINCT up.platform_game_id) as total_games,
  SUM(up.current_score) as total_gamerscore,
  SUM(up.achievements_earned) as achievements_earned,
  SUM(up.total_achievements) as total_achievements,
  ROUND(AVG(up.completion_percentage), 2) as avg_completion
FROM profiles p
JOIN user_progress_v2 up ON up.user_id = p.id
JOIN platforms plat ON plat.id = up.platform_id
WHERE p.id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND plat.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
GROUP BY p.display_name, p.xbox_gamertag;

-- Expected: 
-- total_games: 481 (games with xbox_title_id)
-- total_gamerscore: 327,625
-- Note: 66 games (49,645 GS) missing xbox_title_id didn't migrate

-- X_imThumper_X's PSN stats (for comparison - should be separate if exists)
SELECT 
  p.display_name,
  p.psn_online_id,
  COUNT(DISTINCT up.platform_game_id) as total_games,
  SUM(up.achievements_earned) as trophies_earned,
  SUM(up.total_achievements) as total_trophies
FROM profiles p
JOIN user_progress_v2 up ON up.user_id = p.id
JOIN platforms plat ON plat.id = up.platform_id
WHERE p.id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND plat.code = 'PSN'
GROUP BY p.display_name, p.psn_online_id;

-- ============================================================================
-- PART 3: Verify no cross-platform pollution
-- ============================================================================

SELECT 'Cross-Platform Pollution Check' as section;

-- This should return 0 rows - no games with multiple platform IDs on same platform_game_id
SELECT 
  platform_game_id,
  COUNT(DISTINCT platform_id) as platform_count,
  array_agg(DISTINCT p.code) as platforms
FROM games_v2 g
JOIN platforms p ON p.id = g.platform_id
GROUP BY platform_game_id
HAVING COUNT(DISTINCT platform_id) > 1;

-- ============================================================================
-- PART 4: Duplicate detection (should be none due to composite PKs)
-- ============================================================================

SELECT 'Duplicate Detection' as section;

-- Check for duplicates in user_progress_v2 (should be 0)
SELECT 
  user_id,
  platform_id,
  platform_game_id,
  COUNT(*) as duplicate_count
FROM user_progress_v2
GROUP BY user_id, platform_id, platform_game_id
HAVING COUNT(*) > 1;

-- Check for duplicates in user_achievements_v2 (should be 0)
SELECT 
  user_id,
  platform_id,
  platform_game_id,
  platform_achievement_id,
  COUNT(*) as duplicate_count
FROM user_achievements_v2
GROUP BY user_id, platform_id, platform_game_id, platform_achievement_id
HAVING COUNT(*) > 1;

-- ============================================================================
-- PART 5: Compare old vs new schema totals
-- ============================================================================

SELECT 'Schema Comparison' as section;

-- Compare game counts
SELECT 
  'Old Schema' as schema,
  COUNT(*) as game_count,
  COUNT(DISTINCT xbox_title_id) as unique_xbox_games,
  COUNT(DISTINCT psn_npwr_id) as unique_psn_games,
  COUNT(DISTINCT steam_app_id) as unique_steam_games
FROM game_titles;

SELECT 
  'New Schema (v2)' as schema,
  COUNT(*) as game_count,
  COUNT(CASE WHEN platform_id IN (SELECT id FROM platforms WHERE code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')) THEN 1 END) as xbox_games,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'PSN') THEN 1 END) as psn_games,
  COUNT(CASE WHEN platform_id = (SELECT id FROM platforms WHERE code = 'STEAM') THEN 1 END) as steam_games
FROM games_v2;

-- Compare user progress counts
SELECT 
  'Old Schema user_games' as source,
  COUNT(*) as total_entries
FROM user_games;

SELECT 
  'New Schema user_progress_v2' as source,
  COUNT(*) as total_entries
FROM user_progress_v2;
