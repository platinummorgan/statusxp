-- TEMPORARY: Stop deduplicating until schema rebuild
-- Show raw totals like Xbox API reports
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
  TRUNCATE xbox_leaderboard_cache;
  
  INSERT INTO xbox_leaderboard_cache (user_id, display_name, avatar_url, gamerscore, achievement_count, total_games, updated_at)
  SELECT 
    p.id,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    COALESCE(SUM(ug.xbox_current_gamerscore), 0) as gamerscore,
    COALESCE(COUNT(DISTINCT ua.achievement_id), 0) as achievement_count,
    COUNT(DISTINCT ug.game_title_id) as total_games,
    NOW()
  FROM profiles p
  LEFT JOIN user_games ug ON ug.user_id = p.id
  LEFT JOIN platforms pl ON pl.id = ug.platform_id AND pl.code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')
  LEFT JOIN user_achievements ua ON ua.user_id = p.id
  LEFT JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'xbox'
  WHERE p.show_on_leaderboard = true
    AND p.xbox_xuid IS NOT NULL
  GROUP BY p.id, p.xbox_gamertag, p.xbox_avatar_url
  HAVING COALESCE(SUM(ug.xbox_current_gamerscore), 0) > 0;
END;
$$ LANGUAGE plpgsql;

-- Refresh and verify
SELECT refresh_xbox_leaderboard_cache();

SELECT display_name, gamerscore, total_games
FROM xbox_leaderboard_cache
ORDER BY gamerscore DESC
LIMIT 10;
