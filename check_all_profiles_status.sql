-- Check all profiles with their PSN status
SELECT 
    username,
    psn_account_id,
    psn_online_id,
    psn_sync_status,
    (SELECT COUNT(*) FROM user_games WHERE user_id = profiles.id) as game_count,
    (SELECT SUM(statusxp_effective) FROM user_games WHERE user_id = profiles.id) as total_statusxp
FROM profiles
ORDER BY created_at DESC;
