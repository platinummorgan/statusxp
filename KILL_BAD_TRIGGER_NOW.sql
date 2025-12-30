-- DROP THE BAD TRIGGER AND FUNCTION THAT'S USING HARDCODED OLD VALUES
DROP TRIGGER IF EXISTS calculate_statusxp_on_upsert ON user_games;
DROP FUNCTION IF EXISTS trigger_calculate_statusxp() CASCADE;
DROP FUNCTION IF EXISTS calculate_statusxp_effective(bigint) CASCADE;

-- The correct function is calculate_user_game_statusxp() which uses achievements.base_status_xp
-- No trigger needed - we recalculate manually after syncs

-- Recalculate ALL games with correct values NOW
SELECT calculate_user_game_statusxp();

-- Refresh leaderboard
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;

-- Verify fix
SELECT 
  'Dex-Morgan' as user_name,
  COUNT(*) as total_games,
  SUM(statusxp_effective) as total_statusxp
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'Dex-Morgan';
