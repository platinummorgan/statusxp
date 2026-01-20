-- TEMPORARY FIX: Simpler query, no expensive joins
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
  TRUNCATE xbox_leaderboard_cache;
  
  INSERT INTO xbox_leaderboard_cache (user_id, display_name, avatar_url, gamerscore, achievement_count, total_games, updated_at)
  SELECT 
    ug.user_id,
    p.xbox_gamertag as display_name,
    p.xbox_avatar_url as avatar_url,
    SUM(ug.xbox_current_gamerscore) as gamerscore,
    SUM(ug.xbox_achievements_earned) as achievement_count,
    COUNT(DISTINCT ug.game_title_id) as total_games,
    NOW() as updated_at
  FROM user_games ug
  INNER JOIN profiles p ON p.id = ug.user_id
  INNER JOIN platforms pl ON pl.id = ug.platform_id
  WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    AND p.show_on_leaderboard = true
    AND p.xbox_xuid IS NOT NULL
    AND ug.xbox_current_gamerscore > 0
  GROUP BY ug.user_id, p.xbox_gamertag, p.xbox_avatar_url;
END;
$$ LANGUAGE plpgsql;

-- Refresh
SELECT refresh_xbox_leaderboard_cache();

-- Verify Gordon's score
SELECT display_name, gamerscore, total_games
FROM xbox_leaderboard_cache
WHERE display_name = 'XxlmThumperxX';
