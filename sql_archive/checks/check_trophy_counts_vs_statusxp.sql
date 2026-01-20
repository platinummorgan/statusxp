-- Check what trophy counts would give 15,570
-- vs what base_status_xp would give

-- Your actual trophy counts
SELECT 
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END) as bronze_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END) as silver_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END) as gold_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'platinum' THEN 1 ELSE 0 END) as platinum_count,
  -- Legacy calculation (what leaderboard_cache uses)
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END) * 25 +
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END) * 50 +
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END) * 100 +
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'platinum' THEN 1 ELSE 0 END) * 1000 as legacy_statusxp,
  -- Correct calculation (using base_status_xp)
  SUM(a.base_status_xp) as correct_statusxp
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
  AND ua.platform_id = 1;  -- PSN only
