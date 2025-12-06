-- Backfill trophy breakdown counts from user_trophies table
UPDATE user_games ug
SET 
  bronze_trophies = COALESCE((
    SELECT COUNT(*)
    FROM user_trophies ut
    JOIN trophies t ON ut.trophy_id = t.id
    WHERE ut.user_id = ug.user_id
      AND t.game_title_id = ug.game_title_id
      AND t.tier = 'bronze'
      AND ut.earned_at IS NOT NULL
  ), 0),
  silver_trophies = COALESCE((
    SELECT COUNT(*)
    FROM user_trophies ut
    JOIN trophies t ON ut.trophy_id = t.id
    WHERE ut.user_id = ug.user_id
      AND t.game_title_id = ug.game_title_id
      AND t.tier = 'silver'
      AND ut.earned_at IS NOT NULL
  ), 0),
  gold_trophies = COALESCE((
    SELECT COUNT(*)
    FROM user_trophies ut
    JOIN trophies t ON ut.trophy_id = t.id
    WHERE ut.user_id = ug.user_id
      AND t.game_title_id = ug.game_title_id
      AND t.tier = 'gold'
      AND ut.earned_at IS NOT NULL
  ), 0),
  platinum_trophies = COALESCE((
    SELECT COUNT(*)
    FROM user_trophies ut
    JOIN trophies t ON ut.trophy_id = t.id
    WHERE ut.user_id = ug.user_id
      AND t.game_title_id = ug.game_title_id
      AND t.tier = 'platinum'
      AND ut.earned_at IS NOT NULL
  ), 0)
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
