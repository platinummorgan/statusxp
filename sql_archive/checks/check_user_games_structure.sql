-- Check user_games without platform join
SELECT 
  ug.id,
  gt.name,
  ug.earned_trophies,
  ug.total_trophies,
  ug.bronze_trophies,
  ug.silver_trophies,
  ug.gold_trophies,
  ug.platinum_trophies
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE gt.psn_npwr_id IS NOT NULL
LIMIT 5;
