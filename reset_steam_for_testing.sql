-- Delete all Steam data to test fresh sync
DELETE FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND achievement_id IN (
    SELECT id FROM achievements WHERE platform = 'steam'
  );

DELETE FROM achievements
WHERE platform = 'steam';

DELETE FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = (SELECT id FROM platforms WHERE code = 'Steam');

-- Reset sync status
UPDATE profiles
SET steam_sync_status = NULL,
    steam_sync_progress = 0,
    last_steam_sync_at = NULL
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
