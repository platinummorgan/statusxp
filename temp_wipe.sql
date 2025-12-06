-- Delete all user trophy data
DELETE FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Delete all user games
DELETE FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Delete all trophy definitions (orphaned after deleting user_games)
DELETE FROM trophies WHERE game_title_id NOT IN (SELECT DISTINCT game_title_id FROM user_games);

-- Delete all game titles (orphaned)
DELETE FROM game_titles WHERE id NOT IN (SELECT DISTINCT game_title_id FROM user_games);

-- Delete sync logs
DELETE FROM psn_sync_log WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Reset sync status
UPDATE profiles 
SET psn_sync_status = 'never_synced',
    psn_sync_progress = 0,
    last_psn_sync_at = NULL
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

SELECT 'Database wiped clean' AS status;
