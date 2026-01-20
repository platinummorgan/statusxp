-- Hybrid deduplication: Use xbox_title_id when available, fallback to game_title_id when NULL
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
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
    -- Deduplicate using xbox_title_id (or game_title_id as fallback)
    SELECT 
      user_id,
      SUM(max_gamerscore) as total_gamerscore,
      COUNT(*) as total_games
    FROM (
      SELECT 
        ug.user_id,
        COALESCE(gt.xbox_title_id, ug.game_title_id::text) as unique_game_key,
        MAX(ug.xbox_current_gamerscore) as max_gamerscore
      FROM user_games ug
      JOIN game_titles gt ON ug.game_title_id = gt.id
      JOIN platforms pl ON ug.platform_id = pl.id
      WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
        AND ug.xbox_current_gamerscore IS NOT NULL
        AND ug.xbox_current_gamerscore > 0
      GROUP BY ug.user_id, COALESCE(gt.xbox_title_id, ug.game_title_id::text)
    ) deduplicated_games
    GROUP BY user_id
  ) deduplicated ON deduplicated.user_id = p.id
  LEFT JOIN (
    -- Total achievement count
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

-- Refresh cache
SELECT refresh_xbox_leaderboard_cache();

-- Verify Gordon's results
SELECT 
  display_name,
  gamerscore,
  total_games
FROM xbox_leaderboard_cache
WHERE display_name = 'XxlmThumperxX';
