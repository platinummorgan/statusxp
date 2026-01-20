-- IMMEDIATE FIX: Refresh Steam leaderboard cache
-- This will add SternalJet (and any other missing Steam users) to the leaderboard

SELECT refresh_steam_leaderboard_cache();

-- Verify SternalJet is now in the cache
SELECT 
    display_name,
    achievement_count,
    total_games
FROM steam_leaderboard_cache
WHERE display_name = 'SternalJet';

-- Show updated leaderboard count
SELECT COUNT(*) as total_steam_leaderboard_entries FROM steam_leaderboard_cache;

-- Show top 10
SELECT * FROM steam_leaderboard_cache ORDER BY achievement_count DESC LIMIT 10;
