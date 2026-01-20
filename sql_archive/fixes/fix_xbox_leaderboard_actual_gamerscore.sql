-- ============================================================================
-- FIX XBOX LEADERBOARD - Show actual Xbox gamerscore from user_progress
-- ============================================================================
-- Problem: xbox_leaderboard_cache sums a.score_value (doesn't exist for Xbox)
-- Solution: Sum up.current_score (actual gamerscore from Xbox API stored per-game)
--
-- WHY: Xbox gamerscore should match what players see on their Xbox profile
-- Just like PSN platinums show 172, Xbox gamerscore should show real Microsoft value
-- ============================================================================

BEGIN;

-- Drop old view
DROP VIEW IF EXISTS xbox_leaderboard_cache CASCADE;

-- Create view that shows ACTUAL Xbox gamerscore from Microsoft
-- This matches what players see on their Xbox profile (like PSN platinums = 172)
CREATE OR REPLACE VIEW xbox_leaderboard_cache AS
SELECT 
  up.user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  p.avatar_url,
  -- Sum actual gamerscore from Xbox (stored per-game in user_progress.current_score)
  -- This is the REAL gamerscore from Microsoft, synced from title.achievement.currentGamerscore
  COALESCE(SUM(up.current_score), 0)::bigint as gamerscore,
  -- Count total Xbox achievements earned across all games
  COALESCE(SUM(up.achievements_earned), 0)::integer as achievement_count,
  -- Count total Xbox games with progress
  COUNT(DISTINCT (up.platform_id, up.platform_game_id))::integer as total_games,
  NOW() as updated_at
FROM user_progress up
INNER JOIN profiles p ON p.id = up.user_id
WHERE up.platform_id IN (10, 11, 12)  -- Xbox360, XboxOne, XboxSeriesX
  AND p.show_on_leaderboard = true
  AND up.current_score > 0  -- Only games with gamerscore
GROUP BY up.user_id, p.display_name, p.username, p.avatar_url
HAVING COALESCE(SUM(up.current_score), 0) > 0
ORDER BY gamerscore DESC, total_games DESC;

-- Grant access
GRANT SELECT ON xbox_leaderboard_cache TO authenticated;
GRANT SELECT ON xbox_leaderboard_cache TO anon;

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check Otaku's gamerscore - should match Xbox profile
SELECT 
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
WHERE display_name = 'Otaku';

-- Show top 10 Xbox leaderboard with realistic gamerscore values
SELECT 
  ROW_NUMBER() OVER (ORDER BY gamerscore DESC) as rank,
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
LIMIT 10;

-- Compare: Before fix showed SUM(score_value), after shows SUM(current_score)
-- Before: 66.5M gamerscore (impossible)
-- After: Should show realistic values (e.g., 100K-500K for heavy users)
