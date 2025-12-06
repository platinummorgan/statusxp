-- Delete Lawn Mowing Simulator so it can be re-synced with DLC trophies
DELETE FROM user_trophies 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND trophy_id IN (
    SELECT t.id FROM trophies t
    JOIN game_titles gt ON t.game_title_id = gt.id
    WHERE gt.name LIKE '%Lawn%Mowing%'
  );

DELETE FROM user_games 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND game_title_id IN (
    SELECT id FROM game_titles WHERE name LIKE '%Lawn%Mowing%'
  );

DELETE FROM trophies 
WHERE game_title_id IN (
    SELECT id FROM game_titles WHERE name LIKE '%Lawn%Mowing%'
  );

DELETE FROM game_titles WHERE name LIKE '%Lawn%Mowing%';
