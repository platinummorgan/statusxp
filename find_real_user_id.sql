-- Find ALL user IDs that have data
SELECT user_id, COUNT(*) as game_count
FROM user_games
GROUP BY user_id;

-- Check all profiles
SELECT id, email, psn_account_id, xbox_gamertag
FROM profiles;
