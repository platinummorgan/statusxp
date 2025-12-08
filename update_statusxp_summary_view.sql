-- Drop and recreate user_statusxp_summary view to use new user_games columns
DROP VIEW IF EXISTS user_statusxp_summary CASCADE;

CREATE VIEW user_statusxp_summary AS
SELECT 
  user_id,
  COUNT(*) as total_achievements,
  SUM(statusxp_effective) as total_statusxp,
  COUNT(*) FILTER (WHERE base_completed = true) as base_game_achievements,
  SUM(statusxp_effective) FILTER (WHERE base_completed = true) as base_game_statusxp,
  0 as dlc_achievements,
  0 as dlc_statusxp
FROM user_games
GROUP BY user_id;

-- Test the view
SELECT total_statusxp
FROM user_statusxp_summary
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
