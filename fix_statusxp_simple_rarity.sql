-- ============================================================================
-- StatusXP: Simple rarity-based calculation (NO stack penalties, NO DLC penalties)
-- ============================================================================

-- Create simple calculation function
CREATE OR REPLACE FUNCTION calculate_statusxp_simple(p_user_id uuid)
RETURNS TABLE(
  platform_id BIGINT,
  platform_game_id TEXT,
  statusxp BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    SUM(a.base_status_xp)::BIGINT as statusxp
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND a.include_in_score = true
  GROUP BY ua.platform_id, ua.platform_game_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Update leaderboard with simple calculation
TRUNCATE TABLE leaderboard_cache;

INSERT INTO leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
SELECT
  ua.user_id,
  SUM(a.base_status_xp)::BIGINT as total_statusxp,
  COUNT(DISTINCT (ua.platform_id, ua.platform_game_id))::INTEGER as total_game_entries,
  NOW() as last_updated
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE a.include_in_score = true
  AND p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id
HAVING SUM(a.base_status_xp) > 0;

-- Verify counts
SELECT COUNT(*) as users_updated FROM leaderboard_cache;

-- Show top 10
SELECT 
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
ORDER BY lc.total_statusxp DESC
LIMIT 10;

-- Your score
SELECT 
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
