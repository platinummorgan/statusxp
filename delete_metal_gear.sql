-- Delete Metal Gear Solid from user_games so it gets re-synced
DELETE FROM user_trophies 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
AND trophy_id IN (
    SELECT t.id 
    FROM trophies t 
    WHERE t.game_title_id = 525
);

DELETE FROM user_games 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
AND game_title_id = 525;
