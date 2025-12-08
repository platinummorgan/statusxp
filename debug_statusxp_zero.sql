-- Check why statusxp is 0
SELECT 
  COUNT(*) as total_games,
  COUNT(*) FILTER (WHERE stack_multiplier IS NULL) as null_multiplier,
  COUNT(*) FILTER (WHERE statusxp_raw IS NULL) as null_raw,
  COUNT(*) FILTER (WHERE statusxp_effective IS NULL) as null_effective,
  SUM(statusxp_raw) as total_raw,
  SUM(statusxp_effective) as total_effective
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Sample of games to see what's happening
SELECT 
  gt.name,
  ug.stack_multiplier,
  ug.statusxp_raw,
  ug.statusxp_effective
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
LIMIT 10;
