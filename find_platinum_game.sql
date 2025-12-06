-- Find a game with platinum that we can force re-sync
SELECT 
  ug.id,
  gt.name,
  ug.has_platinum,
  ug.platinum_trophies,
  gt.cover_url
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.has_platinum = true
ORDER BY gt.name
LIMIT 10;
