-- Check xdoscbobbles PSN connection and game data
SELECT 
    p.username,
    p.psn_account_id,
    p.psn_online_id,
    p.psn_sync_status,
    p.psn_sync_error,
    p.last_psn_sync_at,
    (SELECT COUNT(*) FROM user_games WHERE user_id = p.id) as game_count,
    (SELECT SUM(statusxp_effective) FROM user_games WHERE user_id = p.id) as total_statusxp
FROM profiles p 
WHERE p.username = 'xdoscbobbles';
