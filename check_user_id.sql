-- Find what user IDs actually exist in user_games
SELECT DISTINCT user_id, COUNT(*) as game_count
FROM user_games
GROUP BY user_id;

-- Check profiles table for your user
SELECT id, psn_account_id, xbox_gamertag, steam_id
FROM profiles
WHERE id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8';

-- See if there's any data at all in user_games
SELECT COUNT(*) as total_games_all_users FROM user_games;
SELECT COUNT(*) as total_achievements_all_users FROM user_achievements;
