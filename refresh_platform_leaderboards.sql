-- Refresh platform-specific leaderboard caches (they're tables, not materialized views)

-- Call the refresh functions
SELECT refresh_psn_leaderboard_cache();
SELECT refresh_xbox_leaderboard_cache();
SELECT refresh_steam_leaderboard_cache();

-- Verify Dex-Morgan is in all caches
SELECT 'PSN' as platform, * FROM psn_leaderboard_cache WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
UNION ALL
SELECT 'Xbox' as platform, * FROM xbox_leaderboard_cache WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
UNION ALL
SELECT 'Steam' as platform, * FROM steam_leaderboard_cache WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
