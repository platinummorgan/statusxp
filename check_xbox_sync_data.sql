-- Check if Xbox achievements were synced but not games

-- Count Xbox achievements for user
SELECT COUNT(*) as xbox_achievements_count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.platform = 'xbox';

-- Check Xbox sync logs
SELECT 
    id,
    sync_type,
    status,
    started_at,
    completed_at,
    games_processed,
    achievements_synced,
    error_message
FROM xbox_sync_logs
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY started_at DESC
LIMIT 5;
