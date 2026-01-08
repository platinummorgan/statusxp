-- ============================================
-- REFRESH LEADERBOARD CACHES AFTER FIX #2
-- Platform_id fixes completed - refresh all cached leaderboard data
-- ============================================

-- Refresh StatusXP Global Leaderboard (materialized view)
SELECT 'Refreshing StatusXP Global Leaderboard...' as status;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
SELECT 'StatusXP Global Leaderboard refreshed ✓' as status;

-- Refresh PSN Platinum Leaderboard
SELECT 'Refreshing PSN Platinum Leaderboard...' as status;
SELECT refresh_psn_leaderboard_cache();
SELECT 'PSN Platinum Leaderboard refreshed ✓' as status;

-- Refresh Xbox Leaderboard
SELECT 'Refreshing Xbox Leaderboard...' as status;
SELECT refresh_xbox_leaderboard_cache();
SELECT 'Xbox Leaderboard refreshed ✓' as status;

-- Refresh Steam Leaderboard
SELECT 'Refreshing Steam Leaderboard...' as status;
SELECT refresh_steam_leaderboard_cache();
SELECT 'Steam Leaderboard refreshed ✓' as status;

-- Verify cache counts
SELECT 'CACHE VERIFICATION' as status;

SELECT 'StatusXP Global Cache:' as leaderboard, COUNT(*) as entries
FROM leaderboard_cache
UNION ALL
SELECT 'PSN Platinum Cache:', COUNT(*) FROM psn_leaderboard_cache
UNION ALL
SELECT 'Xbox Cache:', COUNT(*) FROM xbox_leaderboard_cache
UNION ALL
SELECT 'Steam Cache:', COUNT(*) FROM steam_leaderboard_cache;

SELECT 'ALL LEADERBOARD CACHES REFRESHED ✓' as status;
