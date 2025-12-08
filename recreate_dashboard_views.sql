-- Recreate the views/tables needed for dashboard

-- user_stats: Aggregated stats per user
CREATE OR REPLACE VIEW user_stats AS
SELECT 
  ug.user_id,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  COUNT(DISTINCT CASE WHEN ug.completion_percent = 100 THEN ug.game_title_id END) as completed_games,
  SUM(ug.earned_trophies) as total_trophies,
  SUM(ug.bronze_trophies) as bronze_count,
  SUM(ug.silver_trophies) as silver_count,
  SUM(ug.gold_trophies) as gold_count,
  SUM(ug.platinum_trophies) as platinum_count,
  SUM(ug.xbox_current_gamerscore) as total_gamerscore
FROM user_games ug
GROUP BY ug.user_id;

-- user_statusxp_summary: StatusXP calculation per user
CREATE OR REPLACE VIEW user_statusxp_summary AS
SELECT 
  ug.user_id,
  SUM(
    CASE 
      -- Platinum trophies: 180 XP each
      WHEN ug.platinum_trophies > 0 THEN ug.platinum_trophies * 180
      ELSE 0
    END +
    -- Gold trophies: 90 XP each
    CASE WHEN ug.gold_trophies > 0 THEN ug.gold_trophies * 90 ELSE 0 END +
    -- Silver trophies: 30 XP each
    CASE WHEN ug.silver_trophies > 0 THEN ug.silver_trophies * 30 ELSE 0 END +
    -- Bronze trophies: 15 XP each
    CASE WHEN ug.bronze_trophies > 0 THEN ug.bronze_trophies * 15 ELSE 0 END +
    -- Xbox achievements: 1 XP each
    CASE WHEN ug.xbox_achievements_earned > 0 THEN ug.xbox_achievements_earned * 1 ELSE 0 END
  ) as total_statusxp
FROM user_games ug
GROUP BY ug.user_id;

-- Grant access
GRANT SELECT ON user_stats TO authenticated;
GRANT SELECT ON user_stats TO anon;
GRANT SELECT ON user_statusxp_summary TO authenticated;
GRANT SELECT ON user_statusxp_summary TO anon;
