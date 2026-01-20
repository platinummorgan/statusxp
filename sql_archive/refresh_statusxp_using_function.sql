-- ============================================================================
-- Use the CORRECT leaderboard refresh function
-- ============================================================================

SELECT refresh_statusxp_leaderboard();

-- Verify
SELECT 
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
