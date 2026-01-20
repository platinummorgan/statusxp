-- Fix the refresh_xbox_leaderboard_cache function to properly populate gamerscore column
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
  -- Clear and rebuild
  TRUNCATE xbox_leaderboard_cache;
  
  INSERT INTO xbox_leaderboard_cache (user_id, display_name, avatar_url, gamerscore, achievement_count, total_games, updated_at)
  SELECT 
    p.id,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    COALESCE(deduplicated.total_gamerscore, 0) as gamerscore,
    COALESCE(achievement_counts.total_achievements, 0) as achievement_count,
    COALESCE(deduplicated.total_games, 0) as total_games,
    NOW()
  FROM profiles p
  LEFT JOIN (
    -- Deduplicated gamerscore by game name
    SELECT 
      user_id,
      SUM(max_gamerscore) as total_gamerscore,
      COUNT(DISTINCT game_name) as total_games
    FROM (
      SELECT 
        ug.user_id,
        gt.name as game_name,
        MAX(ug.xbox_current_gamerscore) as max_gamerscore
      FROM user_games ug
      JOIN game_titles gt ON ug.game_title_id = gt.id
      JOIN platforms pl ON ug.platform_id = pl.id
      WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
        AND ug.xbox_current_gamerscore IS NOT NULL
      GROUP BY ug.user_id, gt.name
    ) deduplicated_games
    GROUP BY user_id
  ) deduplicated ON deduplicated.user_id = p.id
  LEFT JOIN (
    -- Total achievement count (not deduplicated, for reference)
    SELECT 
      user_id,
      COUNT(DISTINCT ua.achievement_id) as total_achievements
    FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE a.platform IN ('xbox')
    GROUP BY user_id
  ) achievement_counts ON achievement_counts.user_id = p.id
  WHERE p.show_on_leaderboard = true
    AND p.xbox_xuid IS NOT NULL
    AND COALESCE(deduplicated.total_gamerscore, 0) > 0;
END;
$$ LANGUAGE plpgsql;

-- Now refresh the cache with the fixed function
SELECT refresh_xbox_leaderboard_cache();

-- Verify results
SELECT 
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
ORDER BY gamerscore DESC
LIMIT 10;
