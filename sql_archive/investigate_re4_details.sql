-- Investigate Resident Evil 4 in detail
SELECT 
  gt.id as game_title_id,
  gt.name,
  gt.xbox_title_id,
  gt.metadata,
  gt.created_at,
  -- Check how many users have this game
  (SELECT COUNT(*) FROM user_games ug WHERE ug.game_title_id = gt.id) as user_count,
  -- Check total gamerscore stored
  (SELECT SUM(xbox_current_gamerscore) FROM user_games ug WHERE ug.game_title_id = gt.id) as total_gamerscore
FROM game_titles gt
WHERE gt.name = 'Resident Evil 4'
ORDER BY gt.created_at;

-- Now check Gordon's specific entries for RE4
SELECT 
  ug.game_title_id,
  gt.name,
  gt.xbox_title_id,
  ug.platform_id,
  p.code as platform_code,
  ug.xbox_current_gamerscore,
  ug.xbox_achievements_earned,
  gt.created_at
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE gt.name = 'Resident Evil 4'
  AND ug.user_id = 'b68ff5b3-c3f1-428f-bcdd-dd3d06f80ba0'
ORDER BY gt.created_at;
